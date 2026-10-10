package com.healthresponse.platform.appointment;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.directory.DirectoryService;
import com.healthresponse.platform.notification.NotificationService;
import com.healthresponse.platform.patient.PatientService;
import com.healthresponse.platform.security.AuthPrincipal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Appointment state machine (server-enforced, the client can never submit a status):
 * REQUESTED -> CONFIRMED | REJECTED | CANCELLED ; CONFIRMED -> COMPLETED | CANCELLED.
 * Slot ownership is guarded by a UNIQUE slot_key that is only populated while REQUESTED/CONFIRMED.
 */
@Service
public class AppointmentService {
    public record AppointmentView(UUID id, UUID patientId, String patientName, UUID doctorId, String doctorName,
                                  Instant startsAt, Instant endsAt, String status, String reason) {}

    private static final Map<String, Set<String>> TRANSITIONS = Map.of(
            "REQUESTED", Set.of("CONFIRMED", "REJECTED", "CANCELLED"),
            "CONFIRMED", Set.of("COMPLETED", "CANCELLED"));

    private final JdbcClient jdbc;
    private final PatientService patients;
    private final DirectoryService directory;
    private final NotificationService notifications;
    private final AuditService audit;

    public AppointmentService(JdbcClient jdbc, PatientService patients, DirectoryService directory,
                              NotificationService notifications, AuditService audit) {
        this.jdbc = jdbc;
        this.patients = patients;
        this.directory = directory;
        this.notifications = notifications;
        this.audit = audit;
    }

    private static final String SELECT = """
            SELECT a.id, a.patient_id, pu.full_name AS patient_name, a.doctor_id, du.full_name AS doctor_name,
                   a.starts_at, a.ends_at, a.status, a.reason, pp.user_id AS patient_user, dp.user_id AS doctor_user
            FROM appointments a
            JOIN patient_profiles pp ON pp.id = a.patient_id JOIN users pu ON pu.id = pp.user_id
            JOIN doctor_profiles dp ON dp.id = a.doctor_id JOIN users du ON du.id = dp.user_id""";

    private record Row(AppointmentView view, UUID patientUser, UUID doctorUser) {}

    private Row load(UUID id) {
        return jdbc.sql(SELECT + " WHERE a.id = :id").param("id", id).query((rs, n) -> new Row(
                new AppointmentView(rs.getObject("id", UUID.class), rs.getObject("patient_id", UUID.class),
                        rs.getString("patient_name"), rs.getObject("doctor_id", UUID.class), rs.getString("doctor_name"),
                        Sql.instant(rs, "starts_at"), Sql.instant(rs, "ends_at"), rs.getString("status"),
                        rs.getString("reason")),
                rs.getObject("patient_user", UUID.class), rs.getObject("doctor_user", UUID.class)))
                .optional().orElseThrow(() -> ApiException.notFound("Appointment"));
    }

    private Row loadAuthorized(AuthPrincipal p, UUID id) {
        Row r = load(id);
        boolean allowed = p.userId().equals(r.patientUser()) || p.userId().equals(r.doctorUser())
                || p.has("APPOINTMENT_ADMIN");
        if (!allowed) {
            audit.denied(p, "APPOINTMENT_ACCESS", "APPOINTMENT", id);
            // 404 rather than 403 so ids of other people's appointments cannot be probed.
            throw ApiException.notFound("Appointment");
        }
        return r;
    }

    public AppointmentView get(AuthPrincipal p, UUID id) { return loadAuthorized(p, id).view(); }

    public DirectoryService.Page<AppointmentView> list(AuthPrincipal p, int page, int size) {
        size = Math.min(Math.max(size, 1), 50);
        page = Math.max(page, 0);
        String scope;
        UUID param;
        if (p.has("APPOINTMENT_ADMIN")) { scope = "1=1"; param = null; }
        else if (p.hasRole("DOCTOR")) { scope = "dp.user_id = :uid"; param = p.userId(); }
        else { scope = "pp.user_id = :uid"; param = p.userId(); }
        var count = jdbc.sql("""
                SELECT COUNT(*) FROM appointments a JOIN patient_profiles pp ON pp.id = a.patient_id
                JOIN doctor_profiles dp ON dp.id = a.doctor_id WHERE """ + scope);
        var query = jdbc.sql(SELECT + " WHERE " + scope + " ORDER BY a.starts_at DESC LIMIT :lim OFFSET :off");
        if (param != null) { count = count.param("uid", param); query = query.param("uid", param); }
        long total = count.query(Long.class).single();
        List<AppointmentView> items = query.param("lim", size).param("off", page * size)
                .query((rs, n) -> new AppointmentView(rs.getObject("id", UUID.class), rs.getObject("patient_id", UUID.class),
                        rs.getString("patient_name"), rs.getObject("doctor_id", UUID.class), rs.getString("doctor_name"),
                        Sql.instant(rs, "starts_at"), Sql.instant(rs, "ends_at"), rs.getString("status"),
                        rs.getString("reason"))).list();
        return new DirectoryService.Page<>(items, page, size, total);
    }

    @Transactional
    public AppointmentView book(AuthPrincipal p, UUID doctorId, Instant startsAt, String reason) {
        UUID patientId = patients.patientIdFor(p.userId());
        Instant slotStart = startsAt.truncatedTo(java.time.temporal.ChronoUnit.SECONDS);
        var date = slotStart.atZone(DirectoryService.CLINIC_ZONE).toLocalDate();
        var slot = directory.slots(doctorId, date).stream().filter(s -> s.startsAt().equals(slotStart)).findFirst()
                .orElseThrow(() -> ApiException.conflict("SLOT_UNAVAILABLE", "That time slot is not available"));
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        try {
            jdbc.sql("""
                    INSERT INTO appointments (id, patient_id, doctor_id, starts_at, ends_at, status, reason, slot_key,
                                              created_at, updated_at)
                    VALUES (:id, :p, :d, :s, :e, 'REQUESTED', :r, :key, :now, :now)""")
                    .param("id", id).param("p", patientId).param("d", doctorId).param("s", Sql.ts(slot.startsAt()))
                    .param("e", Sql.ts(slot.endsAt())).param("r", reason)
                    .param("key", doctorId + "|" + slot.startsAt().getEpochSecond()).param("now", Sql.ts(now)).update();
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("SLOT_TAKEN", "That time slot was just booked by someone else");
        }
        Row r = load(id);
        audit.ok(p, "APPOINTMENT_BOOK", "APPOINTMENT", id);
        notifications.create(r.doctorUser(), "APPOINTMENT_REQUESTED", "New appointment request",
                "A patient requested an appointment. Open the app to review it.", "APPOINTMENT", id);
        return r.view();
    }

    @Transactional
    public AppointmentView confirm(AuthPrincipal p, UUID id) {
        Row r = loadAuthorized(p, id);
        requireDoctorOwner(p, r);
        transition(r, "CONFIRMED", true);
        audit.ok(p, "APPOINTMENT_CONFIRM", "APPOINTMENT", id);
        notifications.create(r.patientUser(), "APPOINTMENT_CONFIRMED", "Appointment confirmed",
                "Your appointment has been confirmed.", "APPOINTMENT", id);
        return load(id).view();
    }

    @Transactional
    public AppointmentView reject(AuthPrincipal p, UUID id) {
        Row r = loadAuthorized(p, id);
        requireDoctorOwner(p, r);
        transition(r, "REJECTED", false);
        audit.ok(p, "APPOINTMENT_REJECT", "APPOINTMENT", id);
        notifications.create(r.patientUser(), "APPOINTMENT_CANCELLED", "Appointment declined",
                "Your appointment request could not be accepted. Please choose another time.", "APPOINTMENT", id);
        return load(id).view();
    }

    @Transactional
    public AppointmentView complete(AuthPrincipal p, UUID id) {
        Row r = loadAuthorized(p, id);
        requireDoctorOwner(p, r);
        transition(r, "COMPLETED", false);
        audit.ok(p, "APPOINTMENT_COMPLETE", "APPOINTMENT", id);
        return load(id).view();
    }

    @Transactional
    public AppointmentView cancel(AuthPrincipal p, UUID id) {
        Row r = loadAuthorized(p, id);
        transition(r, "CANCELLED", false);
        audit.ok(p, "APPOINTMENT_CANCEL", "APPOINTMENT", id);
        UUID other = p.userId().equals(r.patientUser()) ? r.doctorUser() : r.patientUser();
        notifications.create(other, "APPOINTMENT_CANCELLED", "Appointment cancelled",
                "An appointment has been cancelled.", "APPOINTMENT", id);
        return load(id).view();
    }

    @Transactional
    public AppointmentView reschedule(AuthPrincipal p, UUID id, Instant newStart) {
        Row r = loadAuthorized(p, id);
        if (!p.userId().equals(r.patientUser())) throw ApiException.forbidden("Only the patient can reschedule");
        String status = r.view().status();
        if (!status.equals("REQUESTED") && !status.equals("CONFIRMED")) {
            throw ApiException.conflict("INVALID_TRANSITION", "This appointment can no longer be rescheduled");
        }
        Instant start = newStart.truncatedTo(java.time.temporal.ChronoUnit.SECONDS);
        var date = start.atZone(DirectoryService.CLINIC_ZONE).toLocalDate();
        var slot = directory.slots(r.view().doctorId(), date).stream().filter(s -> s.startsAt().equals(start)).findFirst()
                .orElseThrow(() -> ApiException.conflict("SLOT_UNAVAILABLE", "That time slot is not available"));
        try {
            int n = jdbc.sql("""
                    UPDATE appointments SET starts_at = :s, ends_at = :e, status = 'REQUESTED', slot_key = :key,
                           version = version + 1, updated_at = :now
                    WHERE id = :id AND status IN ('REQUESTED', 'CONFIRMED')""")
                    .param("s", Sql.ts(slot.startsAt())).param("e", Sql.ts(slot.endsAt()))
                    .param("key", r.view().doctorId() + "|" + slot.startsAt().getEpochSecond())
                    .param("now", Sql.ts(Instant.now())).param("id", id).update();
            if (n != 1) throw ApiException.conflict("CONFLICT", "The appointment was modified concurrently");
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("SLOT_TAKEN", "That time slot was just booked by someone else");
        }
        audit.ok(p, "APPOINTMENT_RESCHEDULE", "APPOINTMENT", id);
        notifications.create(r.doctorUser(), "APPOINTMENT_RESCHEDULED", "Appointment rescheduled",
                "A patient proposed a new appointment time.", "APPOINTMENT", id);
        return load(id).view();
    }

    private void requireDoctorOwner(AuthPrincipal p, Row r) {
        if (!p.userId().equals(r.doctorUser())) throw ApiException.forbidden("Only the assigned doctor can do this");
    }

    private void transition(Row r, String to, boolean keepSlot) {
        String from = r.view().status();
        if (!TRANSITIONS.getOrDefault(from, Set.of()).contains(to)) {
            throw ApiException.conflict("INVALID_TRANSITION", "Cannot change appointment from " + from + " to " + to);
        }
        int n = jdbc.sql("""
                UPDATE appointments SET status = :to, slot_key = CASE WHEN :keep = TRUE THEN slot_key ELSE NULL END,
                       version = version + 1, updated_at = :now
                WHERE id = :id AND status = :from""")
                .param("to", to).param("keep", keepSlot).param("now", Sql.ts(Instant.now()))
                .param("id", r.view().id()).param("from", from).update();
        if (n != 1) throw ApiException.conflict("CONFLICT", "The appointment was modified concurrently");
    }
}

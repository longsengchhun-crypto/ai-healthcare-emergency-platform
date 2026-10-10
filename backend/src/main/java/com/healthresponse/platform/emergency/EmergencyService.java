package com.healthresponse.platform.emergency;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.directory.DirectoryService;
import com.healthresponse.platform.notification.NotificationService;
import com.healthresponse.platform.patient.PatientService;
import com.healthresponse.platform.security.AuthPrincipal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Backend-authoritative emergency workflow.
 * <pre>
 * CREATED -> SUBMITTED -> ACKNOWLEDGED -> RESPONDER_ASSIGNED -> RESPONDER_EN_ROUTE -> ARRIVED -> RESOLVED
 * SUBMITTED -> REJECTED | CANCELLED ; any non-terminal pre-ARRIVED state -> CANCELLED ; CREATED -> FAILED
 * </pre>
 * Staff actions (acknowledge/assign/status) require EMERGENCY_MANAGE; the owning patient may cancel (false alarm).
 * Nothing here dispatches a real ambulance: status only reflects what authorised staff recorded.
 */
@Service
public class EmergencyService {
    public static final String DISCLAIMER =
            "Demonstration response workflow inside this app. It is not a real emergency dispatch network. "
            + "If you are in danger, call your local emergency number.";

    private static final Map<String, Set<String>> TRANSITIONS = Map.of(
            "CREATED", Set.of("SUBMITTED", "FAILED"),
            "SUBMITTED", Set.of("ACKNOWLEDGED", "REJECTED", "CANCELLED"),
            "ACKNOWLEDGED", Set.of("RESPONDER_ASSIGNED", "CANCELLED"),
            "RESPONDER_ASSIGNED", Set.of("RESPONDER_EN_ROUTE", "CANCELLED"),
            "RESPONDER_EN_ROUTE", Set.of("ARRIVED", "CANCELLED"),
            "ARRIVED", Set.of("RESOLVED"));

    public record Location(double latitude, double longitude, Double accuracyMeters, Instant capturedAt) {}
    public record HistoryEntry(String fromStatus, String toStatus, UUID actorId, String note, Instant at) {}
    public record Assignment(UUID responderId, String responderName, Instant at) {}
    public record EmergencyView(UUID id, String status, String triggerSource, boolean demo, UUID hospitalId,
                                String patientName, String patientPhone, Location location,
                                List<HistoryEntry> history, List<Assignment> assignments,
                                Instant createdAt, Instant updatedAt, boolean duplicateRequest, String disclaimer) {}
    public record CreateCommand(String idempotencyKey, String description, String triggerSource, boolean demo,
                                Double latitude, Double longitude, Double accuracyMeters) {}

    private record Header(UUID id, UUID patientId, UUID patientUser, UUID hospitalId, String status) {}

    private final JdbcClient jdbc;
    private final PatientService patients;
    private final DirectoryService directory;
    private final NotificationService notifications;
    private final AuditService audit;
    private final com.healthresponse.platform.notification.ContactAlertService contactAlerts;

    public EmergencyService(JdbcClient jdbc, PatientService patients, DirectoryService directory,
                            NotificationService notifications, AuditService audit,
                            com.healthresponse.platform.notification.ContactAlertService contactAlerts) {
        this.contactAlerts = contactAlerts;
        this.jdbc = jdbc;
        this.patients = patients;
        this.directory = directory;
        this.notifications = notifications;
        this.audit = audit;
    }

    // ---------------------------------------------------------------- create (idempotent)

    @Transactional
    public EmergencyView create(AuthPrincipal p, CreateCommand c) {
        UUID patientId = patients.patientIdFor(p.userId());
        Optional<UUID> existing = jdbc.sql("SELECT id FROM emergency_events WHERE patient_id = :p AND idempotency_key = :k")
                .param("p", patientId).param("k", c.idempotencyKey()).query(UUID.class).optional();
        if (existing.isPresent()) return view(p, existing.get(), true);

        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        UUID hospitalId = nearestHospital(c.latitude(), c.longitude());
        String source = c.demo() ? "DEMO" : c.triggerSource();
        try {
            jdbc.sql("""
                    INSERT INTO emergency_events (id, patient_id, hospital_id, status, trigger_source, description,
                                                  idempotency_key, is_demo, created_at, updated_at)
                    VALUES (:id, :p, :h, 'CREATED', :src, :d, :k, :demo, :now, :now)""")
                    .param("id", id).param("p", patientId).param("h", hospitalId).param("src", source)
                    .param("d", c.description()).param("k", c.idempotencyKey()).param("demo", c.demo())
                    .param("now", Sql.ts(now)).update();
        } catch (DuplicateKeyException e) {
            // Concurrent retry with the same key: the other transaction won; return its event.
            UUID winner = jdbc.sql("SELECT id FROM emergency_events WHERE patient_id = :p AND idempotency_key = :k")
                    .param("p", patientId).param("k", c.idempotencyKey()).query(UUID.class).single();
            return view(p, winner, true);
        }
        history(id, null, "CREATED", p.userId(), "Event persisted", now);
        if (c.latitude() != null && c.longitude() != null) {
            jdbc.sql("""
                    INSERT INTO emergency_event_locations (id, event_id, latitude, longitude, accuracy_m, captured_at)
                    VALUES (:id, :e, :la, :lo, :ac, :now)""")
                    .param("id", UUID.randomUUID()).param("e", id).param("la", c.latitude()).param("lo", c.longitude())
                    .param("ac", c.accuracyMeters()).param("now", Sql.ts(now)).update();
        }
        // Event is durable; now place it in the response queue.
        setStatus(id, "CREATED", "SUBMITTED", Instant.now());
        history(id, "CREATED", "SUBMITTED", null, "Placed in response queue", Instant.now());
        history(id, "SUBMITTED", "SUBMITTED", null, contactAlerts.queue(id, patientId, c.demo()), Instant.now());
        notifyStaff(id, hospitalId, "EMERGENCY_SUBMITTED", "New emergency event",
                "A new emergency event is waiting in the response queue.");
        audit.ok(p, "EMERGENCY_CREATE", "EMERGENCY", id);
        return view(p, id, false);
    }

    private UUID nearestHospital(Double lat, Double lon) {
        if (lat == null || lon == null) return null;
        return directory.hospitals(null, null, lat, lon, 0, 1).items().stream()
                .filter(h -> h.distanceKm() != null).findFirst().map(DirectoryService.HospitalView::id).orElse(null);
    }

    private void notifyStaff(UUID eventId, UUID hospitalId, String category, String title, String body) {
        List<UUID> staff = jdbc.sql("""
                SELECT DISTINCT ur.user_id FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                LEFT JOIN hospital_staff hs ON hs.user_id = ur.user_id
                WHERE r.name = 'HOSPITAL_STAFF' AND (CAST(:h AS UUID) IS NULL OR hs.hospital_id = CAST(:h AS UUID))""")
                .param("h", hospitalId).query(UUID.class).list();
        for (UUID u : staff) {
            notifications.create(u, category, title, body, "EMERGENCY", eventId);
        }
    }

    // ---------------------------------------------------------------- read

    public EmergencyView get(AuthPrincipal p, UUID id) { return view(p, id, false); }

    public List<EmergencyView> list(AuthPrincipal p, String statusFilter, int limit) {
        limit = Math.min(Math.max(limit, 1), 100);
        List<UUID> ids;
        if (p.has("EMERGENCY_QUEUE_VIEW") && !p.hasRole("PATIENT")) {
            String sql = """
                    SELECT e.id FROM emergency_events e
                    WHERE (CAST(:s AS VARCHAR) IS NULL OR e.status = CAST(:s AS VARCHAR))
                      AND (:all = TRUE OR e.hospital_id IS NULL OR e.hospital_id IN (SELECT hospital_id FROM hospital_staff WHERE user_id = :u))
                      AND (:doctor = FALSE OR e.id IN (SELECT event_id FROM responder_assignments WHERE responder_id = :u))
                    ORDER BY e.created_at DESC LIMIT :l""";
            ids = jdbc.sql(sql).param("s", statusFilter).param("all", p.hasRole("SYSTEM_ADMIN"))
                    .param("doctor", p.hasRole("DOCTOR") && !p.hasRole("HOSPITAL_STAFF") && !p.hasRole("SYSTEM_ADMIN"))
                    .param("u", p.userId()).param("l", limit).query(UUID.class).list();
        } else {
            ids = jdbc.sql("""
                    SELECT id FROM emergency_events WHERE patient_id = :p AND (CAST(:s AS VARCHAR) IS NULL OR status = CAST(:s AS VARCHAR))
                    ORDER BY created_at DESC LIMIT :l""")
                    .param("p", patients.patientIdFor(p.userId())).param("s", statusFilter).param("l", limit)
                    .query(UUID.class).list();
        }
        List<EmergencyView> out = new ArrayList<>();
        for (UUID id : ids) out.add(view(p, id, false));
        return out;
    }

    private Header header(UUID id) {
        return jdbc.sql("""
                SELECT e.id, e.patient_id, pp.user_id, e.hospital_id, e.status FROM emergency_events e
                JOIN patient_profiles pp ON pp.id = e.patient_id WHERE e.id = :id""").param("id", id)
                .query((rs, n) -> new Header(rs.getObject("id", UUID.class), rs.getObject("patient_id", UUID.class),
                        rs.getObject("user_id", UUID.class), rs.getObject("hospital_id", UUID.class),
                        rs.getString("status"))).optional().orElseThrow(() -> ApiException.notFound("Emergency event"));
    }

    private boolean isOwner(AuthPrincipal p, Header h) { return p.userId().equals(h.patientUser()); }

    private boolean canViewAsStaff(AuthPrincipal p, Header h) {
        if (!p.has("EMERGENCY_QUEUE_VIEW")) return false;
        if (p.hasRole("SYSTEM_ADMIN") || h.hospitalId() == null) return true;
        boolean member = jdbc.sql("SELECT COUNT(*) FROM hospital_staff WHERE user_id = :u AND hospital_id = :h")
                .param("u", p.userId()).param("h", h.hospitalId()).query(Integer.class).single() > 0;
        boolean assigned = jdbc.sql("SELECT COUNT(*) FROM responder_assignments WHERE event_id = :e AND responder_id = :u")
                .param("e", h.id()).param("u", p.userId()).query(Integer.class).single() > 0;
        return member || assigned;
    }

    private EmergencyView view(AuthPrincipal p, UUID id, boolean duplicate) {
        Header h = header(id);
        boolean staff = !isOwner(p, h) && canViewAsStaff(p, h);
        if (!isOwner(p, h) && !staff) {
            audit.denied(p, "EMERGENCY_ACCESS", "EMERGENCY", id);
            throw ApiException.notFound("Emergency event");
        }
        if (staff) audit.ok(p, "EMERGENCY_VIEW_STAFF", "EMERGENCY", id);
        var e = jdbc.sql("""
                SELECT e.trigger_source, e.is_demo, e.created_at, e.updated_at, u.full_name, u.phone
                FROM emergency_events e JOIN patient_profiles pp ON pp.id = e.patient_id JOIN users u ON u.id = pp.user_id
                WHERE e.id = :id""").param("id", id)
                .query((rs, n) -> new Object[]{rs.getString("trigger_source"), rs.getBoolean("is_demo"),
                        Sql.instant(rs, "created_at"), Sql.instant(rs, "updated_at"), rs.getString("full_name"),
                        rs.getString("phone")}).single();
        Location loc = jdbc.sql("""
                SELECT latitude, longitude, accuracy_m, captured_at FROM emergency_event_locations
                WHERE event_id = :id ORDER BY captured_at DESC LIMIT 1""").param("id", id)
                .query((rs, n) -> new Location(rs.getDouble("latitude"), rs.getDouble("longitude"),
                        rs.getObject("accuracy_m") == null ? null : rs.getDouble("accuracy_m"),
                        Sql.instant(rs, "captured_at"))).optional().orElse(null);
        List<HistoryEntry> hist = jdbc.sql("""
                SELECT from_status, to_status, actor_id, note, created_at FROM emergency_event_history
                WHERE event_id = :id ORDER BY created_at, id""").param("id", id)
                .query((rs, n) -> new HistoryEntry(rs.getString("from_status"), rs.getString("to_status"),
                        rs.getObject("actor_id", UUID.class), rs.getString("note"), Sql.instant(rs, "created_at"))).list();
        List<Assignment> assigned = jdbc.sql("""
                SELECT ra.responder_id, u.full_name, ra.created_at FROM responder_assignments ra
                JOIN users u ON u.id = ra.responder_id WHERE ra.event_id = :id ORDER BY ra.created_at""").param("id", id)
                .query((rs, n) -> new Assignment(rs.getObject("responder_id", UUID.class), rs.getString("full_name"),
                        Sql.instant(rs, "created_at"))).list();
        return new EmergencyView(id, header(id).status(), (String) e[0], (Boolean) e[1], h.hospitalId(),
                staff ? (String) e[4] : null, staff ? (String) e[5] : null, loc, hist, assigned,
                (Instant) e[2], (Instant) e[3], duplicate, DISCLAIMER);
    }

    // ---------------------------------------------------------------- staff & patient actions

    @Transactional
    public EmergencyView acknowledge(AuthPrincipal p, UUID id) {
        Header h = requireStaff(p, id);
        changeStatus(p, h, "ACKNOWLEDGED", "Acknowledged by hospital staff");
        jdbc.sql("UPDATE emergency_events SET acknowledged_by = :u WHERE id = :id").param("u", p.userId()).param("id", id).update();
        notifyPatient(h, "EMERGENCY_ACKNOWLEDGED", "Emergency acknowledged",
                "Hospital staff acknowledged your emergency request.");
        audit.ok(p, "EMERGENCY_ACKNOWLEDGE", "EMERGENCY", id);
        return view(p, id, false);
    }

    @Transactional
    public EmergencyView assign(AuthPrincipal p, UUID id, UUID responderId) {
        Header h = requireStaff(p, id);
        boolean validResponder = jdbc.sql("""
                SELECT COUNT(*) FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                JOIN users u ON u.id = ur.user_id AND u.status = 'ACTIVE'
                WHERE ur.user_id = :u AND r.name IN ('DOCTOR', 'HOSPITAL_STAFF')""")
                .param("u", responderId).query(Integer.class).single() > 0;
        if (!validResponder) throw ApiException.badRequest("INVALID_RESPONDER", "Selected user cannot be assigned as a responder");
        if (h.status().equals("ACKNOWLEDGED")) {
            changeStatus(p, h, "RESPONDER_ASSIGNED", "Responder assigned");
        } else if (!h.status().equals("RESPONDER_ASSIGNED")) {
            throw ApiException.conflict("INVALID_TRANSITION", "A responder can only be assigned to an acknowledged event");
        }
        jdbc.sql("""
                INSERT INTO responder_assignments (id, event_id, responder_id, assigned_by, created_at)
                VALUES (:id, :e, :r, :by, :now)""").param("id", UUID.randomUUID()).param("e", id)
                .param("r", responderId).param("by", p.userId()).param("now", Sql.ts(Instant.now())).update();
        notifications.create(responderId, "EMERGENCY_ASSIGNED", "Emergency assignment",
                "You were assigned to an emergency event.", "EMERGENCY", id);
        notifyPatient(h, "RESPONDER_STATUS_CHANGED", "Responder assigned",
                "A responder was assigned to your emergency request.");
        audit.ok(p, "EMERGENCY_ASSIGN", "EMERGENCY", id);
        return view(p, id, false);
    }

    @Transactional
    public EmergencyView updateStatus(AuthPrincipal p, UUID id, String to, String note) {
        Header h = requireStaff(p, id);
        if (!Set.of("RESPONDER_EN_ROUTE", "ARRIVED", "RESOLVED", "REJECTED").contains(to)) {
            throw ApiException.badRequest("INVALID_STATUS", "Status cannot be set directly; use the dedicated action");
        }
        changeStatus(p, h, to, note);
        notifyPatient(h, "RESPONDER_STATUS_CHANGED", "Emergency status updated", "Your emergency status was updated.");
        audit.ok(p, "EMERGENCY_STATUS_" + to, "EMERGENCY", id);
        return view(p, id, false);
    }

    @Transactional
    public EmergencyView cancel(AuthPrincipal p, UUID id, String note) {
        Header h = header(id);
        boolean staff = !isOwner(p, h) && p.has("EMERGENCY_MANAGE") && canViewAsStaff(p, h);
        if (!isOwner(p, h) && !staff) {
            audit.denied(p, "EMERGENCY_CANCEL", "EMERGENCY", id);
            throw ApiException.notFound("Emergency event");
        }
        changeStatus(p, h, "CANCELLED", note == null ? "Cancelled" : note);
        if (isOwner(p, h)) {
            notifyStaff(id, h.hospitalId(), "EMERGENCY_CANCELLED", "Emergency cancelled",
                    "A patient cancelled an emergency request (false alarm).");
        }
        audit.ok(p, "EMERGENCY_CANCEL", "EMERGENCY", id);
        return view(p, id, false);
    }

    private Header requireStaff(AuthPrincipal p, UUID id) {
        Header h = header(id);
        if (!p.has("EMERGENCY_MANAGE") || !canViewAsStaff(p, h)) {
            audit.denied(p, "EMERGENCY_MANAGE", "EMERGENCY", id);
            throw ApiException.notFound("Emergency event");
        }
        return h;
    }

    private void changeStatus(AuthPrincipal p, Header h, String to, String note) {
        if (!TRANSITIONS.getOrDefault(h.status(), Set.of()).contains(to)) {
            throw ApiException.conflict("INVALID_TRANSITION",
                    "Cannot change emergency from " + h.status() + " to " + to);
        }
        Instant now = Instant.now();
        setStatus(h.id(), h.status(), to, now);
        history(h.id(), h.status(), to, p.userId(), note, now);
    }

    /** Optimistic transition: fails if another request already moved the event. */
    private void setStatus(UUID id, String from, String to, Instant now) {
        int n = jdbc.sql("UPDATE emergency_events SET status = :to, updated_at = :now, version = version + 1 WHERE id = :id AND status = :from")
                .param("to", to).param("now", Sql.ts(now)).param("id", id).param("from", from).update();
        if (n != 1) throw ApiException.conflict("CONFLICT", "The emergency was updated by someone else. Refresh and retry.");
    }

    private void history(UUID eventId, String from, String to, UUID actor, String note, Instant at) {
        jdbc.sql("""
                INSERT INTO emergency_event_history (id, event_id, from_status, to_status, actor_id, note, created_at)
                VALUES (:id, :e, :f, :t, :a, :n, :at)""").param("id", UUID.randomUUID()).param("e", eventId)
                .param("f", from).param("t", to).param("a", actor).param("n", note).param("at", Sql.ts(at)).update();
    }

    private void notifyPatient(Header h, String category, String title, String body) {
        notifications.create(h.patientUser(), category, title, body, "EMERGENCY", h.id());
    }
}

package com.healthresponse.platform.medication;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.patient.PatientService;
import com.healthresponse.platform.security.AuthPrincipal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Medication information and reminders. This service stores what the user entered or what a clinician prescribed;
 * it never recommends or changes doses.
 */
@Service
public class MedicationService {
    public record MedicationView(UUID id, String name, String dosage, String instructions, String source) {}
    public record ReminderView(UUID id, UUID medicationId, String medicationName, LocalTime timeOfDay, String timezone,
                               LocalDate startDate, LocalDate endDate, boolean active, Instant nextOccurrence) {}

    private final JdbcClient jdbc;
    private final PatientService patients;
    private final AuditService audit;

    public MedicationService(JdbcClient jdbc, PatientService patients, AuditService audit) {
        this.jdbc = jdbc;
        this.patients = patients;
        this.audit = audit;
    }

    public List<MedicationView> medications(AuthPrincipal p) {
        return jdbc.sql("SELECT id, name, dosage, instructions, source FROM medications WHERE patient_id = :p ORDER BY created_at DESC")
                .param("p", patients.patientIdFor(p.userId()))
                .query((rs, n) -> new MedicationView(rs.getObject("id", UUID.class), rs.getString("name"),
                        rs.getString("dosage"), rs.getString("instructions"), rs.getString("source"))).list();
    }

    @Transactional
    public MedicationView addMedication(AuthPrincipal p, String name, String dosage, String instructions) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO medications (id, patient_id, name, dosage, instructions, source, created_at)
                VALUES (:id, :p, :n, :d, :i, 'USER_ENTERED', :now)""")
                .param("id", id).param("p", patients.patientIdFor(p.userId())).param("n", name).param("d", dosage)
                .param("i", instructions).param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, "MEDICATION_ADD", "MEDICATION", id);
        return new MedicationView(id, name, dosage, instructions, "USER_ENTERED");
    }

    @Transactional
    public ReminderView addReminder(AuthPrincipal p, UUID medicationId, LocalTime time, String timezone,
                                    LocalDate start, LocalDate end) {
        ZoneId zone = zone(timezone);
        ownMedication(p, medicationId);
        if (end != null && end.isBefore(start)) throw ApiException.badRequest("INVALID_DATES", "End date is before start date");
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO medication_reminders (id, medication_id, time_of_day, timezone, start_date, end_date, active, created_at)
                VALUES (:id, :m, :t, :tz, :s, :e, TRUE, :now)""")
                .param("id", id).param("m", medicationId).param("t", java.sql.Time.valueOf(time)).param("tz", zone.getId())
                .param("s", java.sql.Date.valueOf(start)).param("e", end == null ? null : java.sql.Date.valueOf(end))
                .param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, "REMINDER_CREATE", "REMINDER", id);
        return reminder(p, id);
    }

    @Transactional
    public ReminderView updateReminder(AuthPrincipal p, UUID id, Boolean active, LocalTime time, LocalDate end) {
        reminder(p, id); // ownership check
        jdbc.sql("""
                UPDATE medication_reminders SET active = COALESCE(:a, active), time_of_day = COALESCE(:t, time_of_day),
                       end_date = COALESCE(:e, end_date) WHERE id = :id""")
                .param("a", active).param("t", time == null ? null : java.sql.Time.valueOf(time))
                .param("e", end == null ? null : java.sql.Date.valueOf(end)).param("id", id).update();
        return reminder(p, id);
    }

    public List<ReminderView> reminders(AuthPrincipal p) {
        return jdbc.sql(REMINDER_SQL + " WHERE m.patient_id = :p ORDER BY r.time_of_day")
                .param("p", patients.patientIdFor(p.userId())).query((rs, n) -> map(rs)).list();
    }

    public ReminderView reminder(AuthPrincipal p, UUID id) {
        return jdbc.sql(REMINDER_SQL + " WHERE r.id = :id AND m.patient_id = :p").param("id", id)
                .param("p", patients.patientIdFor(p.userId())).query((rs, n) -> map(rs)).optional()
                .orElseThrow(() -> ApiException.notFound("Reminder"));
    }

    @Transactional
    public void recordAdherence(AuthPrincipal p, UUID reminderId, String outcome) {
        reminder(p, reminderId);
        jdbc.sql("INSERT INTO medication_adherence_events (id, reminder_id, outcome, recorded_at) VALUES (:id, :r, :o, :now)")
                .param("id", UUID.randomUUID()).param("r", reminderId).param("o", outcome)
                .param("now", Sql.ts(Instant.now())).update();
    }

    private static final String REMINDER_SQL = """
            SELECT r.id, r.medication_id, m.name, r.time_of_day, r.timezone, r.start_date, r.end_date, r.active
            FROM medication_reminders r JOIN medications m ON m.id = r.medication_id""";

    private ReminderView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        LocalTime t = rs.getTime("time_of_day").toLocalTime();
        LocalDate s = rs.getDate("start_date").toLocalDate();
        LocalDate e = rs.getDate("end_date") == null ? null : rs.getDate("end_date").toLocalDate();
        boolean active = rs.getBoolean("active");
        return new ReminderView(rs.getObject("id", UUID.class), rs.getObject("medication_id", UUID.class),
                rs.getString("name"), t, rs.getString("timezone"), s, e, active,
                active ? nextOccurrence(t, ZoneId.of(rs.getString("timezone")), s, e, Instant.now()) : null);
    }

    /** Next firing time (UTC) honouring the reminder's own timezone, start/end dates and DST. */
    static Instant nextOccurrence(LocalTime time, ZoneId zone, LocalDate start, LocalDate end, Instant now) {
        ZonedDateTime local = now.atZone(zone);
        LocalDate day = local.toLocalDate();
        if (day.isBefore(start)) day = start;
        ZonedDateTime candidate = day.atTime(time).atZone(zone);
        if (!candidate.toInstant().isAfter(now)) candidate = day.plusDays(1).atTime(time).atZone(zone);
        if (end != null && candidate.toLocalDate().isAfter(end)) return null;
        return candidate.toInstant();
    }

    private ZoneId zone(String tz) {
        try {
            return ZoneId.of(tz);
        } catch (Exception e) {
            throw ApiException.badRequest("INVALID_TIMEZONE", "Unknown timezone");
        }
    }

    private void ownMedication(AuthPrincipal p, UUID medicationId) {
        int n = jdbc.sql("SELECT COUNT(*) FROM medications WHERE id = :m AND patient_id = :p").param("m", medicationId)
                .param("p", patients.patientIdFor(p.userId())).query(Integer.class).single();
        if (n == 0) throw ApiException.notFound("Medication");
    }
}

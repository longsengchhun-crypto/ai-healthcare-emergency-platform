package com.healthresponse.platform.patient;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.security.AuthPrincipal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PatientService {
    public record Profile(UUID id, String fullName, String email, String phone, LocalDate dateOfBirth, String gender,
                          String bloodGroup, String allergies, String conditions, String address) {}
    public record ProfileUpdate(String fullName, String phone, LocalDate dateOfBirth, String gender,
                                String bloodGroup, String allergies, String conditions, String address) {}
    public record Contact(UUID id, String name, String relationship, String phone, int priority) {}

    private final JdbcClient jdbc;
    private final AuditService audit;

    public PatientService(JdbcClient jdbc, AuditService audit) {
        this.jdbc = jdbc;
        this.audit = audit;
    }

    /** Resolves the caller's own patient profile id; every patient-scoped query starts from this, never from client input. */
    public UUID patientIdFor(UUID userId) {
        return jdbc.sql("SELECT id FROM patient_profiles WHERE user_id = :u").param("u", userId)
                .query(UUID.class).optional()
                .orElseThrow(() -> ApiException.forbidden("No patient profile is associated with this account"));
    }

    public Profile get(AuthPrincipal p) {
        return jdbc.sql("""
                SELECT pp.id, u.full_name, u.email, u.phone, pp.date_of_birth, pp.gender, pp.blood_group,
                       pp.allergies, pp.conditions, pp.address
                FROM patient_profiles pp JOIN users u ON u.id = pp.user_id WHERE pp.user_id = :u""")
                .param("u", p.userId())
                .query((rs, n) -> new Profile(rs.getObject("id", UUID.class), rs.getString("full_name"),
                        rs.getString("email"), rs.getString("phone"),
                        rs.getDate("date_of_birth") == null ? null : rs.getDate("date_of_birth").toLocalDate(),
                        rs.getString("gender"), rs.getString("blood_group"), rs.getString("allergies"),
                        rs.getString("conditions"), rs.getString("address")))
                .optional().orElseThrow(() -> ApiException.notFound("Patient profile"));
    }

    @Transactional
    public Profile update(AuthPrincipal p, ProfileUpdate u) {
        if (u.dateOfBirth() != null && u.dateOfBirth().isAfter(LocalDate.now())) {
            throw ApiException.badRequest("INVALID_DATE", "Date of birth cannot be in the future");
        }
        Instant now = Instant.now();
        jdbc.sql("""
                UPDATE patient_profiles SET
                  date_of_birth = COALESCE(:dob, date_of_birth), gender = COALESCE(:g, gender),
                  blood_group = COALESCE(:bg, blood_group), allergies = COALESCE(:al, allergies),
                  conditions = COALESCE(:co, conditions), address = COALESCE(:ad, address), updated_at = :now
                WHERE user_id = :u""")
                .param("dob", u.dateOfBirth() == null ? null : java.sql.Date.valueOf(u.dateOfBirth()))
                .param("g", u.gender()).param("bg", u.bloodGroup()).param("al", u.allergies())
                .param("co", u.conditions()).param("ad", u.address()).param("now", Sql.ts(now))
                .param("u", p.userId()).update();
        if (u.fullName() != null || u.phone() != null) {
            jdbc.sql("UPDATE users SET full_name = COALESCE(:n, full_name), phone = COALESCE(:ph, phone), updated_at = :now WHERE id = :u")
                    .param("n", u.fullName()).param("ph", u.phone()).param("now", Sql.ts(now)).param("u", p.userId()).update();
        }
        audit.ok(p, "PATIENT_PROFILE_UPDATE", "PATIENT_PROFILE", p.userId());
        return get(p);
    }

    public List<Contact> contacts(AuthPrincipal p) {
        return jdbc.sql("SELECT id, name, relationship, phone, priority FROM emergency_contacts WHERE patient_id = :p ORDER BY priority, created_at")
                .param("p", patientIdFor(p.userId()))
                .query((rs, n) -> new Contact(rs.getObject("id", UUID.class), rs.getString("name"),
                        rs.getString("relationship"), rs.getString("phone"), rs.getInt("priority")))
                .list();
    }

    @Transactional
    public Contact addContact(AuthPrincipal p, String name, String relationship, String phone, int priority) {
        UUID patientId = patientIdFor(p.userId());
        int count = jdbc.sql("SELECT COUNT(*) FROM emergency_contacts WHERE patient_id = :p").param("p", patientId)
                .query(Integer.class).single();
        if (count >= 5) throw ApiException.conflict("CONTACT_LIMIT", "A maximum of 5 emergency contacts is allowed");
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO emergency_contacts (id, patient_id, name, relationship, phone, priority, created_at)
                VALUES (:id, :p, :n, :r, :ph, :pr, :now)""")
                .param("id", id).param("p", patientId).param("n", name).param("r", relationship).param("ph", phone)
                .param("pr", priority).param("now", Sql.ts(Instant.now())).update();
        return new Contact(id, name, relationship, phone, priority);
    }

    @Transactional
    public void deleteContact(AuthPrincipal p, UUID contactId) {
        int n = jdbc.sql("DELETE FROM emergency_contacts WHERE id = :id AND patient_id = :p")
                .param("id", contactId).param("p", patientIdFor(p.userId())).update();
        if (n == 0) throw ApiException.notFound("Emergency contact");
    }

    public Map<String, Object> privacySummary(AuthPrincipal p) {
        UUID patientId = patientIdFor(p.userId());
        List<Map<String, Object>> grants = jdbc.sql("""
                SELECT g.id, u.full_name AS doctor_name, g.expires_at
                FROM record_access_grants g JOIN doctor_profiles d ON d.id = g.doctor_id JOIN users u ON u.id = d.user_id
                WHERE g.patient_id = :p AND g.revoked_at IS NULL""").param("p", patientId)
                .query((rs, n) -> Map.<String, Object>of("grantId", rs.getObject("id", UUID.class).toString(),
                        "doctorName", rs.getString("doctor_name")))
                .list();
        return Map.of("recordAccessGrants", grants);
    }

    /** Who else accessed this patient's records or profile, newest first (the patient's own actions are excluded). */
    public List<Map<String, Object>> activity(AuthPrincipal p) {
        UUID patientId = patientIdFor(p.userId());
        return jdbc.sql("""
                SELECT a.action, a.outcome, a.actor_role, a.created_at, u.full_name
                FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_id
                WHERE (a.actor_id IS NULL OR a.actor_id <> :uid)
                  AND (a.action LIKE 'RECORD_%' OR a.action LIKE 'DOCUMENT_%' OR a.action LIKE 'ACCESS_%'
                       OR a.action LIKE 'EMERGENCY_VIEW%')
                  AND ((a.target_type = 'PATIENT' AND a.target_id = :pid)
                       OR (a.target_type = 'MEDICAL_RECORD' AND a.target_id IN
                           (SELECT CAST(r.id AS VARCHAR) FROM medical_records r WHERE r.patient_id = :patient)))
                ORDER BY a.created_at DESC LIMIT 40""")
                .param("uid", p.userId()).param("pid", patientId.toString()).param("patient", patientId)
                .query((rs, n) -> {
                    java.util.Map<String, Object> row = new java.util.LinkedHashMap<>();
                    row.put("action", rs.getString("action"));
                    row.put("outcome", rs.getString("outcome"));
                    row.put("actorRole", rs.getString("actor_role"));
                    row.put("actorName", rs.getString("full_name"));
                    row.put("at", Sql.instant(rs, "created_at"));
                    return row;
                }).list();
    }
}

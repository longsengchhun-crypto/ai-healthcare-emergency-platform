package com.healthresponse.platform.vitals;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.patient.PatientService;
import com.healthresponse.platform.security.AuthPrincipal;
import com.healthresponse.platform.vitals.VitalRules.Assessment;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Patient-entered health measurements. Always scoped to the signed-in patient's own profile. */
@Service
public class VitalService {
    public record VitalView(UUID id, String type, double value1, Double value2, String unit, String note,
                            Instant measuredAt, String level, String code) {}
    public record SummaryItem(String type, String unit, VitalView latest, long count30d, Double average30d) {}

    private static final int LIST_LIMIT = 200;

    private final JdbcClient jdbc;
    private final PatientService patients;
    private final AuditService audit;

    public VitalService(JdbcClient jdbc, PatientService patients, AuditService audit) {
        this.jdbc = jdbc;
        this.patients = patients;
        this.audit = audit;
    }

    @Transactional
    public VitalView add(AuthPrincipal p, String type, double value1, Double value2, String note, Instant measuredAt) {
        if (!VitalRules.TYPES.contains(type)) throw ApiException.badRequest("INVALID_TYPE", "Unknown measurement type");
        String problem = VitalRules.implausible(type, value1, value2);
        if (problem != null) throw ApiException.badRequest("IMPLAUSIBLE_VALUE", problem);
        Instant now = Instant.now();
        Instant when = measuredAt == null ? now : measuredAt;
        if (when.isAfter(now.plus(Duration.ofMinutes(5)))) {
            throw ApiException.badRequest("INVALID_TIME", "The measurement time is in the future");
        }
        if (when.isBefore(now.minus(3650, ChronoUnit.DAYS))) {
            throw ApiException.badRequest("INVALID_TIME", "The measurement time is too far in the past");
        }
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO vital_readings (id, patient_id, type, value1, value2, note, measured_at, created_at)
                VALUES (:id, :p, :t, :v1, :v2, :n, :m, :now)""")
                .param("id", id).param("p", patients.patientIdFor(p.userId())).param("t", type)
                .param("v1", value1).param("v2", type.equals("BLOOD_PRESSURE") ? value2 : null)
                .param("n", note == null || note.isBlank() ? null : note.trim()).param("m", Sql.ts(when))
                .param("now", Sql.ts(now)).update();
        audit.ok(p, "VITAL_ADD", "VITAL", id);
        return get(p, id);
    }

    public List<VitalView> list(AuthPrincipal p, String type, int days) {
        if (type != null && !VitalRules.TYPES.contains(type)) {
            throw ApiException.badRequest("INVALID_TYPE", "Unknown measurement type");
        }
        int window = Math.min(Math.max(days, 1), 3650);
        Instant since = Instant.now().minus(window, ChronoUnit.DAYS);
        return jdbc.sql("""
                SELECT id, type, value1, value2, note, measured_at FROM vital_readings
                WHERE patient_id = :p AND measured_at >= :since AND (CAST(:t AS VARCHAR) IS NULL OR type = :t)
                ORDER BY measured_at DESC LIMIT :lim""")
                .param("p", patients.patientIdFor(p.userId())).param("since", Sql.ts(since)).param("t", type)
                .param("lim", LIST_LIMIT).query((rs, n) -> map(rs)).list();
    }

    public List<SummaryItem> summary(AuthPrincipal p) {
        UUID patient = patients.patientIdFor(p.userId());
        Instant since = Instant.now().minus(30, ChronoUnit.DAYS);
        List<SummaryItem> out = new ArrayList<>();
        for (String type : List.of("BLOOD_PRESSURE", "HEART_RATE", "BLOOD_GLUCOSE", "OXYGEN_SATURATION",
                "TEMPERATURE", "WEIGHT")) {
            VitalView latest = jdbc.sql("""
                    SELECT id, type, value1, value2, note, measured_at FROM vital_readings
                    WHERE patient_id = :p AND type = :t ORDER BY measured_at DESC LIMIT 1""")
                    .param("p", patient).param("t", type).query((rs, n) -> map(rs)).optional().orElse(null);
            long count = jdbc.sql("""
                    SELECT COUNT(*) FROM vital_readings WHERE patient_id = :p AND type = :t AND measured_at >= :s""")
                    .param("p", patient).param("t", type).param("s", Sql.ts(since)).query(Long.class).single();
            Double avg = count == 0 ? null : jdbc.sql("""
                    SELECT AVG(value1) FROM vital_readings WHERE patient_id = :p AND type = :t AND measured_at >= :s""")
                    .param("p", patient).param("t", type).param("s", Sql.ts(since)).query(Double.class).single();
            out.add(new SummaryItem(type, VitalRules.UNITS.get(type), latest, count,
                    avg == null ? null : Math.round(avg * 10) / 10.0));
        }
        return out;
    }

    @Transactional
    public void delete(AuthPrincipal p, UUID id) {
        int n = jdbc.sql("DELETE FROM vital_readings WHERE id = :id AND patient_id = :p")
                .param("id", id).param("p", patients.patientIdFor(p.userId())).update();
        if (n == 0) throw ApiException.notFound("Measurement"); // also hides other people's ids
        audit.ok(p, "VITAL_DELETE", "VITAL", id);
    }

    private VitalView get(AuthPrincipal p, UUID id) {
        return jdbc.sql("""
                SELECT id, type, value1, value2, note, measured_at FROM vital_readings
                WHERE id = :id AND patient_id = :p""").param("id", id).param("p", patients.patientIdFor(p.userId()))
                .query((rs, n) -> map(rs)).optional().orElseThrow(() -> ApiException.notFound("Measurement"));
    }

    private VitalView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        String type = rs.getString("type");
        double v1 = rs.getBigDecimal("value1").doubleValue();
        java.math.BigDecimal b2 = rs.getBigDecimal("value2");
        Double v2 = b2 == null ? null : b2.doubleValue();
        Assessment a = VitalRules.assess(type, v1, v2);
        return new VitalView(rs.getObject("id", UUID.class), type, v1, v2, VitalRules.UNITS.get(type),
                rs.getString("note"), Sql.instant(rs, "measured_at"), a.level(), a.code());
    }
}

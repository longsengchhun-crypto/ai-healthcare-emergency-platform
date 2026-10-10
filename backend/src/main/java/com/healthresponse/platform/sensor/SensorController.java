package com.healthresponse.platform.sensor;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/**
 * Stores candidate-incident evidence from the on-device detector. Evidence is capped and only retained when the
 * user opted in on the device. Server-side analysis here is a simple re-check and is always labelled "possible".
 */
@RestController
@RequestMapping("/api/v1/sensor-events")
@PreAuthorize("hasAuthority('EMERGENCY_CREATE')")
public class SensorController {
    public record Reading(@NotBlank @Pattern(regexp = "^(ACCELEROMETER|GYROSCOPE)$") String sensor,
                          double x, double y, double z, @NotNull Instant recordedAt) {}
    public record DetectionRequest(boolean simulated, Double peakAcceleration, Double rotationRate,
                                   Integer inactivitySeconds,
                                   @Pattern(regexp = "^(PENDING|USER_SAFE|EMERGENCY_CREATED|COUNTDOWN_EXPIRED_NOT_ENABLED)$") String outcome,
                                   UUID emergencyEventId, @NotNull Instant detectedAt,
                                   @Size(max = 200) List<@Valid Reading> readings) {}

    private static final double ACCEL_THRESHOLD_MS2 = 25.0;

    private final JdbcClient jdbc;
    private final AuditService audit;

    public SensorController(JdbcClient jdbc, AuditService audit) {
        this.jdbc = jdbc;
        this.audit = audit;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> record(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody DetectionRequest r) {
        if (r.emergencyEventId() != null) {
            int own = jdbc.sql("""
                    SELECT COUNT(*) FROM emergency_events e JOIN patient_profiles pp ON pp.id = e.patient_id
                    WHERE e.id = :e AND pp.user_id = :u""").param("e", r.emergencyEventId()).param("u", p.userId())
                    .query(Integer.class).single();
            if (own == 0) throw ApiException.badRequest("INVALID_EVENT", "Unknown emergency event");
        }
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO accident_detection_events (id, user_id, is_simulated, peak_acceleration, rotation_rate,
                       inactivity_seconds, outcome, emergency_event_id, detected_at)
                VALUES (:id, :u, :sim, :pa, :rr, :in, :o, :e, :at)""")
                .param("id", id).param("u", p.userId()).param("sim", r.simulated()).param("pa", r.peakAcceleration())
                .param("rr", r.rotationRate()).param("in", r.inactivitySeconds())
                .param("o", r.outcome() == null ? "PENDING" : r.outcome()).param("e", r.emergencyEventId())
                .param("at", Sql.ts(r.detectedAt())).update();
        if (r.readings() != null) {
            for (Reading rd : r.readings()) {
                jdbc.sql("""
                        INSERT INTO sensor_readings (id, detection_id, sensor, x, y, z, recorded_at)
                        VALUES (:id, :d, :s, :x, :y, :z, :t)""")
                        .param("id", UUID.randomUUID()).param("d", id).param("s", rd.sensor()).param("x", rd.x())
                        .param("y", rd.y()).param("z", rd.z()).param("t", Sql.ts(rd.recordedAt())).update();
            }
        }
        audit.ok(p, "SENSOR_EVENT", "DETECTION", id);
        boolean strong = r.peakAcceleration() != null && r.peakAcceleration() >= ACCEL_THRESHOLD_MS2
                && r.inactivitySeconds() != null && r.inactivitySeconds() >= 5;
        return Map.of("id", id, "assessment", strong ? "POSSIBLE_INCIDENT" : "NOT_SIGNIFICANT",
                "note", "A phone-only sensor heuristic can only flag a possible incident; it never confirms an accident.",
                "simulated", r.simulated());
    }
}

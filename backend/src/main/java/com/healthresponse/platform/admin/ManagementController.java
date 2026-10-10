package com.healthresponse.platform.admin;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Hospital / department / doctor management and patient consent endpoints. */
@RestController
@RequestMapping("/api/v1")
public class ManagementController {
    public record HospitalRequest(@NotBlank @Size(max = 200) String name, @Size(max = 255) String address,
                                  @Size(max = 100) String city, @Size(max = 32) String phone,
                                  @DecimalMin("-90") @DecimalMax("90") Double latitude,
                                  @DecimalMin("-180") @DecimalMax("180") Double longitude) {}
    public record HospitalPatch(@Size(max = 200) String name, @Size(max = 255) String address,
                                @Size(max = 100) String city, @Size(max = 32) String phone,
                                Boolean active) {}
    public record DepartmentRequest(@NotBlank @Size(max = 120) String name) {}
    public record AffiliationRequest(@NotNull UUID hospitalId, UUID departmentId) {}
    public record DoctorPatch(@Size(max = 120) String specialty, @Size(max = 1000) String bio,
                              @Size(max = 60) String licenseNumber) {}
    public record Window(@Min(1) @Max(7) int dayOfWeek, @NotNull LocalTime startTime, @NotNull LocalTime endTime,
                         @Min(10) @Max(120) Integer slotMinutes) {}
    public record AvailabilityRequest(@NotNull @Size(max = 21) List<@Valid Window> windows) {}
    public record ConsentRequest(@NotBlank @Size(max = 60) String purpose, boolean granted) {}

    private final JdbcClient jdbc;
    private final AuditService audit;

    public ManagementController(JdbcClient jdbc, AuditService audit) {
        this.jdbc = jdbc;
        this.audit = audit;
    }

    // ---------------------------------------------------------------- hospitals
    @PostMapping("/admin/hospitals")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('DIRECTORY_MANAGE')")
    public Map<String, Object> createHospital(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody HospitalRequest r) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO hospitals (id, name, address, city, phone, latitude, longitude, is_demo, created_at)
                VALUES (:id, :n, :a, :c, :p, :la, :lo, FALSE, :now)""")
                .param("id", id).param("n", r.name()).param("a", r.address()).param("c", r.city())
                .param("p", r.phone()).param("la", r.latitude()).param("lo", r.longitude())
                .param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, "HOSPITAL_CREATE", "HOSPITAL", id);
        return Map.of("id", id);
    }

    @PatchMapping("/admin/hospitals/{id}")
    @PreAuthorize("hasAuthority('DIRECTORY_MANAGE')")
    public Map<String, Object> patchHospital(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                             @Valid @RequestBody HospitalPatch r) {
        int n = jdbc.sql("""
                UPDATE hospitals SET name = COALESCE(:n, name), address = COALESCE(:a, address),
                       city = COALESCE(:c, city), phone = COALESCE(:p, phone), active = COALESCE(:act, active)
                WHERE id = :id""").param("n", r.name()).param("a", r.address()).param("c", r.city())
                .param("p", r.phone()).param("act", r.active()).param("id", id).update();
        if (n == 0) throw ApiException.notFound("Hospital");
        audit.ok(p, "HOSPITAL_UPDATE", "HOSPITAL", id);
        return Map.of("id", id);
    }

    @PostMapping("/admin/hospitals/{id}/departments")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('DIRECTORY_MANAGE')")
    public Map<String, Object> addDepartment(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                             @Valid @RequestBody DepartmentRequest r) {
        if (jdbc.sql("SELECT COUNT(*) FROM hospitals WHERE id = :id").param("id", id).query(Integer.class).single() == 0) {
            throw ApiException.notFound("Hospital");
        }
        UUID dep = UUID.randomUUID();
        jdbc.sql("INSERT INTO hospital_departments (id, hospital_id, name) VALUES (:d, :h, :n)")
                .param("d", dep).param("h", id).param("n", r.name().trim()).update();
        audit.ok(p, "DEPARTMENT_CREATE", "HOSPITAL", id);
        return Map.of("id", dep);
    }

    @DeleteMapping("/admin/departments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('DIRECTORY_MANAGE')")
    @Transactional
    public void deleteDepartment(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        jdbc.sql("UPDATE doctor_hospital_affiliations SET department_id = NULL WHERE department_id = :id").param("id", id).update();
        int n = jdbc.sql("DELETE FROM hospital_departments WHERE id = :id").param("id", id).update();
        if (n == 0) throw ApiException.notFound("Department");
        audit.ok(p, "DEPARTMENT_DELETE", "DEPARTMENT", id);
    }

    @GetMapping("/admin/doctors")
    @PreAuthorize("hasAnyAuthority('DOCTOR_VERIFY', 'DIRECTORY_MANAGE')")
    public List<Map<String, Object>> allDoctors() {
        return jdbc.sql("""
                SELECT d.id, u.full_name, u.email, d.specialty, d.license_number, d.verification_status, d.is_demo
                FROM doctor_profiles d JOIN users u ON u.id = d.user_id ORDER BY u.full_name""")
                .query((rs, n) -> Map.<String, Object>of("id", rs.getObject("id", UUID.class),
                        "fullName", rs.getString("full_name"), "email", rs.getString("email"),
                        "specialty", rs.getString("specialty"),
                        "licenseNumber", rs.getString("license_number") == null ? "" : rs.getString("license_number"),
                        "verificationStatus", rs.getString("verification_status"), "demo", rs.getBoolean("is_demo")))
                .list();
    }

    @PostMapping("/admin/doctors/{id}/affiliation")
    @PreAuthorize("hasAuthority('DIRECTORY_MANAGE')")
    @Transactional
    public Map<String, Object> affiliate(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                         @Valid @RequestBody AffiliationRequest r) {
        if (jdbc.sql("SELECT COUNT(*) FROM doctor_profiles WHERE id = :id").param("id", id).query(Integer.class).single() == 0
                || jdbc.sql("SELECT COUNT(*) FROM hospitals WHERE id = :id").param("id", r.hospitalId()).query(Integer.class).single() == 0) {
            throw ApiException.notFound("Doctor or hospital");
        }
        jdbc.sql("DELETE FROM doctor_hospital_affiliations WHERE doctor_id = :d AND hospital_id = :h")
                .param("d", id).param("h", r.hospitalId()).update();
        jdbc.sql("INSERT INTO doctor_hospital_affiliations (doctor_id, hospital_id, department_id) VALUES (:d, :h, :dep)")
                .param("d", id).param("h", r.hospitalId()).param("dep", r.departmentId()).update();
        audit.ok(p, "DOCTOR_AFFILIATE", "DOCTOR", id);
        return Map.of("doctorId", id, "hospitalId", r.hospitalId());
    }

    // ---------------------------------------------------------------- doctor self-service
    private UUID doctorId(AuthPrincipal p) {
        return jdbc.sql("SELECT id FROM doctor_profiles WHERE user_id = :u").param("u", p.userId()).query(UUID.class)
                .optional().orElseThrow(() -> ApiException.forbidden("No doctor profile for this account"));
    }

    @PatchMapping("/doctors/me")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    public Map<String, Object> patchMe(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody DoctorPatch r) {
        UUID id = doctorId(p);
        // Changing the licence invalidates a previous verification: an administrator must re-verify.
        boolean licenceChanged = r.licenseNumber() != null;
        jdbc.sql("""
                UPDATE doctor_profiles SET specialty = COALESCE(:s, specialty), bio = COALESCE(:b, bio),
                       license_number = COALESCE(:l, license_number),
                       verification_status = CASE WHEN :reset = TRUE AND verification_status = 'VERIFIED'
                                                  THEN 'PENDING' ELSE verification_status END
                WHERE id = :id""").param("s", r.specialty()).param("b", r.bio()).param("l", r.licenseNumber())
                .param("reset", licenceChanged).param("id", id).update();
        audit.ok(p, "DOCTOR_PROFILE_UPDATE", "DOCTOR", id);
        return Map.of("id", id);
    }

    @GetMapping("/doctors/me/availability")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    public List<Map<String, Object>> myAvailability(@AuthenticationPrincipal AuthPrincipal p) {
        return jdbc.sql("""
                SELECT day_of_week, start_time, end_time, slot_minutes FROM doctor_availability
                WHERE doctor_id = :d ORDER BY day_of_week, start_time""").param("d", doctorId(p))
                .query((rs, n) -> Map.<String, Object>of("dayOfWeek", rs.getInt("day_of_week"),
                        "startTime", rs.getTime("start_time").toLocalTime().toString(),
                        "endTime", rs.getTime("end_time").toLocalTime().toString(),
                        "slotMinutes", rs.getInt("slot_minutes"))).list();
    }

    /** Replaces the weekly schedule. Already-booked appointments are untouched. */
    @PutMapping("/doctors/me/availability")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    @Transactional
    public Map<String, Object> setAvailability(@AuthenticationPrincipal AuthPrincipal p,
                                               @Valid @RequestBody AvailabilityRequest r) {
        UUID id = doctorId(p);
        for (Window w : r.windows()) {
            if (!w.endTime().isAfter(w.startTime())) {
                throw ApiException.badRequest("INVALID_WINDOW", "End time must be after start time");
            }
        }
        jdbc.sql("DELETE FROM doctor_availability WHERE doctor_id = :d").param("d", id).update();
        for (Window w : r.windows()) {
            jdbc.sql("""
                    INSERT INTO doctor_availability (id, doctor_id, day_of_week, start_time, end_time, slot_minutes)
                    VALUES (:id, :d, :dow, :s, :e, :m)""").param("id", UUID.randomUUID()).param("d", id)
                    .param("dow", w.dayOfWeek()).param("s", java.sql.Time.valueOf(w.startTime()))
                    .param("e", java.sql.Time.valueOf(w.endTime())).param("m", w.slotMinutes() == null ? 30 : w.slotMinutes())
                    .update();
        }
        audit.ok(p, "DOCTOR_AVAILABILITY_SET", "DOCTOR", id);
        return Map.of("windows", r.windows().size());
    }

    // ---------------------------------------------------------------- consent
    @PostMapping("/consents")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> consent(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody ConsentRequest r) {
        UUID id = UUID.randomUUID();
        jdbc.sql("INSERT INTO consent_records (id, user_id, purpose, granted, created_at) VALUES (:id, :u, :p, :g, :now)")
                .param("id", id).param("u", p.userId()).param("p", r.purpose()).param("g", r.granted())
                .param("now", Sql.ts(Instant.now())).update();
        audit.record(p, "CONSENT_RECORDED", "CONSENT", id, "SUCCESS", r.purpose() + "=" + r.granted());
        return Map.of("id", id);
    }

    /** Latest decision per purpose. */
    @GetMapping("/consents")
    public Map<String, Boolean> consents(@AuthenticationPrincipal AuthPrincipal p) {
        Map<String, Boolean> out = new java.util.LinkedHashMap<>();
        jdbc.sql("SELECT purpose, granted FROM consent_records WHERE user_id = :u ORDER BY created_at, id")
                .param("u", p.userId()).query((rs, n) -> {
                    out.put(rs.getString(1), rs.getBoolean(2));
                    return null;
                }).list();
        return out;
    }
}

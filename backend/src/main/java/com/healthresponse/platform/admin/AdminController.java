package com.healthresponse.platform.admin;

import com.healthresponse.platform.auth.UserRepository;
import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.directory.DirectoryService.Page;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Operational endpoints for the hospital/administrator dashboard. Every handler declares its required permission. */
@RestController
@RequestMapping("/api/v1")
public class AdminController {
    public record UserRow(UUID id, String email, String fullName, String status, List<String> roles, Instant createdAt) {}
    public record AuditRow(UUID id, UUID actorId, String actorRole, String action, String targetType, String targetId,
                           String outcome, String detail, Instant createdAt) {}
    public record StatusRequest(@NotBlank @Pattern(regexp = "^(ACTIVE|SUSPENDED|DEACTIVATED)$") String status) {}
    public record RoleRequest(@NotBlank @Pattern(regexp = "^(PATIENT|DOCTOR|HOSPITAL_STAFF|SYSTEM_ADMIN)$") String role) {}
    public record VerificationRequest(@NotBlank @Pattern(regexp = "^(UNVERIFIED|PENDING|VERIFIED|REJECTED)$") String status,
                                      @Size(max = 500) String note) {}
    public record SettingRequest(@NotBlank @Size(max = 500) String value) {}

    private final JdbcClient jdbc;
    private final AuditService audit;
    private final UserRepository users;

    public AdminController(JdbcClient jdbc, AuditService audit, UserRepository users) {
        this.jdbc = jdbc;
        this.audit = audit;
        this.users = users;
    }

    // ------------------------------------------------------------ users & roles
    @GetMapping("/admin/users")
    @PreAuthorize("hasAuthority('USER_ADMIN')")
    public Page<UserRow> users(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "25") int size,
                               @RequestParam(required = false) String q) {
        size = Math.min(Math.max(size, 1), 100);
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase() + "%";
        long total = jdbc.sql("SELECT COUNT(*) FROM users WHERE (CAST(:q AS VARCHAR) IS NULL OR LOWER(email) LIKE CAST(:q AS VARCHAR) OR LOWER(full_name) LIKE CAST(:q AS VARCHAR))")
                .param("q", like).query(Long.class).single();
        List<UserRow> rows = jdbc.sql("""
                SELECT id, email, full_name, status, created_at FROM users
                WHERE (CAST(:q AS VARCHAR) IS NULL OR LOWER(email) LIKE CAST(:q AS VARCHAR) OR LOWER(full_name) LIKE CAST(:q AS VARCHAR))
                ORDER BY created_at DESC LIMIT :l OFFSET :o""").param("q", like).param("l", size).param("o", Math.max(page, 0) * size)
                .query((rs, n) -> new UserRow(rs.getObject("id", UUID.class), rs.getString("email"), rs.getString("full_name"),
                        rs.getString("status"), List.of(), Sql.instant(rs, "created_at"))).list().stream()
                .map(u -> new UserRow(u.id(), u.email(), u.fullName(), u.status(),
                        users.roleNames(u.id()).stream().sorted().toList(), u.createdAt())).toList();
        return new Page<>(rows, Math.max(page, 0), size, total);
    }

    @PatchMapping("/admin/users/{id}/status")
    @PreAuthorize("hasAuthority('USER_ADMIN')")
    @Transactional
    public Map<String, String> setStatus(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                         @Valid @RequestBody StatusRequest r) {
        if (id.equals(p.userId())) throw ApiException.badRequest("SELF_CHANGE", "You cannot change your own status");
        int n = jdbc.sql("UPDATE users SET status = :s, updated_at = :now WHERE id = :id AND deleted_at IS NULL")
                .param("s", r.status()).param("now", Sql.ts(Instant.now())).param("id", id).update();
        if (n == 0) throw ApiException.notFound("User");
        if (!"ACTIVE".equals(r.status())) users.revokeAllSessions(id);
        audit.record(p, "USER_STATUS_CHANGE", "USER", id, "SUCCESS", "status=" + r.status());
        return Map.of("status", r.status());
    }

    @PostMapping("/admin/users/{id}/roles")
    @PreAuthorize("hasAuthority('USER_ADMIN')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void addRole(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id, @Valid @RequestBody RoleRequest r) {
        if (id.equals(p.userId())) throw ApiException.badRequest("SELF_CHANGE", "You cannot change your own roles");
        int exists = jdbc.sql("SELECT COUNT(*) FROM users WHERE id = :id").param("id", id).query(Integer.class).single();
        if (exists == 0) throw ApiException.notFound("User");
        jdbc.sql("DELETE FROM user_roles WHERE user_id = :u").param("u", id).update();
        jdbc.sql("INSERT INTO user_roles (user_id, role_id) SELECT :u, id FROM roles WHERE name = :r")
                .param("u", id).param("r", r.role()).update();
        users.revokeAllSessions(id); // force re-authentication under the new role
        audit.record(p, "USER_ROLE_CHANGE", "USER", id, "SUCCESS", "role=" + r.role());
    }

    /** Minimal responder directory (id, name, role) for assignment pickers; exposes no contact or medical data. */
    @GetMapping("/emergencies/responders")
    @PreAuthorize("hasAuthority('EMERGENCY_MANAGE')")
    public List<Map<String, Object>> responders() {
        return jdbc.sql("""
                SELECT u.id, u.full_name, r.name AS role FROM users u
                JOIN user_roles ur ON ur.user_id = u.id JOIN roles r ON r.id = ur.role_id
                WHERE r.name IN ('DOCTOR', 'HOSPITAL_STAFF') AND u.status = 'ACTIVE' AND u.deleted_at IS NULL
                ORDER BY u.full_name""")
                .query((rs, n) -> Map.<String, Object>of("id", rs.getObject("id", UUID.class),
                        "fullName", rs.getString("full_name"), "role", rs.getString("role"))).list();
    }

    // ------------------------------------------------------------ doctor verification
    @PostMapping("/admin/doctors/{id}/verification")
    @PreAuthorize("hasAuthority('DOCTOR_VERIFY')")
    @Transactional
    public Map<String, String> verify(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                      @Valid @RequestBody VerificationRequest r) {
        int n = jdbc.sql("UPDATE doctor_profiles SET verification_status = :s WHERE id = :id")
                .param("s", r.status()).param("id", id).update();
        if (n == 0) throw ApiException.notFound("Doctor");
        jdbc.sql("""
                INSERT INTO doctor_verification_records (id, doctor_id, status, reviewed_by, note, created_at)
                VALUES (:id, :d, :s, :u, :n, :now)""").param("id", UUID.randomUUID()).param("d", id).param("s", r.status())
                .param("u", p.userId()).param("n", r.note()).param("now", Sql.ts(Instant.now())).update();
        audit.record(p, "DOCTOR_VERIFICATION", "DOCTOR", id, "SUCCESS", "status=" + r.status());
        return Map.of("status", r.status());
    }

    // ------------------------------------------------------------ audit log
    @GetMapping("/admin/audit-logs")
    @PreAuthorize("hasAuthority('AUDIT_VIEW')")
    public Page<AuditRow> audit(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size,
                                @RequestParam(required = false) String action,
                                @RequestParam(required = false) String outcome) {
        size = Math.min(Math.max(size, 1), 200);
        long total = jdbc.sql("SELECT COUNT(*) FROM audit_logs WHERE (CAST(:a AS VARCHAR) IS NULL OR action = CAST(:a AS VARCHAR)) AND (CAST(:o AS VARCHAR) IS NULL OR outcome = CAST(:o AS VARCHAR))")
                .param("a", action).param("o", outcome).query(Long.class).single();
        List<AuditRow> rows = jdbc.sql("""
                SELECT id, actor_id, actor_role, action, target_type, target_id, outcome, detail, created_at FROM audit_logs
                WHERE (CAST(:a AS VARCHAR) IS NULL OR action = CAST(:a AS VARCHAR)) AND (CAST(:o AS VARCHAR) IS NULL OR outcome = CAST(:o AS VARCHAR))
                ORDER BY created_at DESC LIMIT :l OFFSET :off""").param("a", action).param("o", outcome).param("l", size)
                .param("off", Math.max(page, 0) * size)
                .query((rs, n) -> new AuditRow(rs.getObject("id", UUID.class), rs.getObject("actor_id", UUID.class),
                        rs.getString("actor_role"), rs.getString("action"), rs.getString("target_type"),
                        rs.getString("target_id"), rs.getString("outcome"), rs.getString("detail"),
                        Sql.instant(rs, "created_at"))).list();
        return new Page<>(rows, Math.max(page, 0), size, total);
    }

    // ------------------------------------------------------------ overview (real aggregates only)
    @GetMapping("/admin/overview")
    @PreAuthorize("hasAuthority('EMERGENCY_QUEUE_VIEW')")
    public Map<String, Object> overview() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("emergenciesByStatus", counts("SELECT status, COUNT(*) FROM emergency_events GROUP BY status"));
        out.put("appointmentsByStatus", counts("SELECT status, COUNT(*) FROM appointments GROUP BY status"));
        out.put("doctorsByVerification", counts("SELECT verification_status, COUNT(*) FROM doctor_profiles GROUP BY verification_status"));
        out.put("notificationDeliveries", counts("SELECT status, COUNT(*) FROM notification_delivery_attempts GROUP BY status"));
        out.put("pendingAcknowledgements", jdbc.sql("SELECT COUNT(*) FROM emergency_events WHERE status = 'SUBMITTED'")
                .query(Long.class).single());
        out.put("generatedAt", Instant.now());
        return out;
    }

    private Map<String, Long> counts(String sql) {
        Map<String, Long> m = new LinkedHashMap<>();
        jdbc.sql(sql).query((rs, n) -> {
            m.put(rs.getString(1), rs.getLong(2));
            return null;
        }).list();
        return m;
    }

    // ------------------------------------------------------------ settings
    @GetMapping("/system/settings")
    public Map<String, String> settings() {
        Map<String, String> m = new LinkedHashMap<>();
        jdbc.sql("SELECT setting_key, setting_value FROM system_settings ORDER BY setting_key").query((rs, n) -> {
            m.put(rs.getString(1), rs.getString(2));
            return null;
        }).list();
        return m;
    }

    @PutMapping("/admin/settings/{key}")
    @PreAuthorize("hasAuthority('SETTINGS_MANAGE')")
    @Transactional
    public Map<String, String> setSetting(@AuthenticationPrincipal AuthPrincipal p, @PathVariable String key,
                                          @Valid @RequestBody SettingRequest r) {
        int n = jdbc.sql("UPDATE system_settings SET setting_value = :v, updated_at = :now WHERE setting_key = :k")
                .param("v", r.value()).param("now", Sql.ts(Instant.now())).param("k", key).update();
        if (n == 0) throw ApiException.notFound("Setting");
        audit.record(p, "SETTING_CHANGE", "SETTING", key, "SUCCESS", null);
        return Map.of(key, r.value());
    }

    // ------------------------------------------------------------ account deactivation (self-service)
    @DeleteMapping("/users/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void deactivateSelf(@AuthenticationPrincipal AuthPrincipal p) {
        jdbc.sql("UPDATE users SET status = 'DEACTIVATED', deleted_at = :now, updated_at = :now WHERE id = :id")
                .param("now", Sql.ts(Instant.now())).param("id", p.userId()).update();
        jdbc.sql("DELETE FROM device_tokens WHERE user_id = :u").param("u", p.userId()).update();
        users.revokeAllSessions(p.userId());
        audit.record(p, "ACCOUNT_DEACTIVATE", "USER", p.userId(), "SUCCESS", null);
    }
}

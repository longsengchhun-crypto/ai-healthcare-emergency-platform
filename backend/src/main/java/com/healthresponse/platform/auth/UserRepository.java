package com.healthresponse.platform.auth;

import com.healthresponse.platform.security.AuthPrincipal;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class UserRepository {
    public record UserRow(UUID id, String email, String passwordHash, String fullName, String status,
                          int failedLogins, Instant lockedUntil) {}

    private final JdbcClient jdbc;

    public UserRepository(JdbcClient jdbc) { this.jdbc = jdbc; }

    public Optional<UserRow> findByEmail(String email) {
        return jdbc.sql("""
                SELECT id, email, password_hash, full_name, status, failed_logins, locked_until
                FROM users WHERE email = :email AND deleted_at IS NULL""")
                .param("email", email)
                .query((rs, n) -> new UserRow(rs.getObject("id", UUID.class), rs.getString("email"),
                        rs.getString("password_hash"), rs.getString("full_name"), rs.getString("status"),
                        rs.getInt("failed_logins"),
                        rs.getTimestamp("locked_until") == null ? null : rs.getTimestamp("locked_until").toInstant()))
                .optional();
    }

    public boolean emailExists(String email) {
        return jdbc.sql("SELECT COUNT(*) FROM users WHERE email = :e").param("e", email)
                .query(Integer.class).single() > 0;
    }

    public UUID insertUser(String email, String hash, String fullName, String phone, String roleName) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        jdbc.sql("""
                INSERT INTO users (id, email, password_hash, full_name, phone, created_at, updated_at)
                VALUES (:id, :email, :hash, :name, :phone, :now, :now)""")
                .param("id", id).param("email", email).param("hash", hash).param("name", fullName)
                .param("phone", phone).param("now", java.sql.Timestamp.from(now)).update();
        jdbc.sql("INSERT INTO user_roles (user_id, role_id) SELECT :u, id FROM roles WHERE name = :r")
                .param("u", id).param("r", roleName).update();
        return id;
    }

    public void recordFailedLogin(UUID id, int failures, Instant lockedUntil) {
        jdbc.sql("UPDATE users SET failed_logins = :f, locked_until = :l WHERE id = :id")
                .param("f", failures).param("l", lockedUntil == null ? null : java.sql.Timestamp.from(lockedUntil))
                .param("id", id).update();
    }

    public void clearFailedLogins(UUID id) {
        jdbc.sql("UPDATE users SET failed_logins = 0, locked_until = NULL WHERE id = :id").param("id", id).update();
    }

    public void updatePassword(UUID id, String hash) {
        jdbc.sql("UPDATE users SET password_hash = :h, failed_logins = 0, locked_until = NULL, updated_at = :now WHERE id = :id")
                .param("h", hash).param("now", java.sql.Timestamp.from(Instant.now())).param("id", id).update();
    }

    public Optional<AuthPrincipal> loadPrincipal(UUID userId) {
        var user = jdbc.sql("SELECT email FROM users WHERE id = :id AND status = 'ACTIVE' AND deleted_at IS NULL")
                .param("id", userId).query(String.class).optional();
        if (user.isEmpty()) return Optional.empty();
        List<String> roles = jdbc.sql("""
                SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = :id""")
                .param("id", userId).query(String.class).list();
        List<String> perms = jdbc.sql("""
                SELECT DISTINCT p.code FROM user_roles ur
                JOIN role_permissions rp ON rp.role_id = ur.role_id
                JOIN permissions p ON p.id = rp.permission_id WHERE ur.user_id = :id""")
                .param("id", userId).query(String.class).list();
        return Optional.of(new AuthPrincipal(userId, user.get(), new HashSet<>(roles), new HashSet<>(perms)));
    }

    public void revokeAllSessions(UUID userId) {
        jdbc.sql("UPDATE refresh_token_sessions SET revoked_at = :now WHERE user_id = :u AND revoked_at IS NULL")
                .param("now", java.sql.Timestamp.from(Instant.now())).param("u", userId).update();
    }

    public Set<String> roleNames(UUID userId) {
        return new HashSet<>(jdbc.sql("""
                SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = :id""")
                .param("id", userId).query(String.class).list());
    }
}

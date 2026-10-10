package com.healthresponse.platform.auth;

import com.healthresponse.platform.auth.UserRepository.UserRow;
import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.security.AppProperties;
import com.healthresponse.platform.security.JwtService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    public record TokenPair(String accessToken, String refreshToken, int expiresInSeconds) {}

    static final int MAX_FAILED_LOGINS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository users;
    private final JdbcClient jdbc;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final AuditService audit;
    private final ResetTokenSender resetSender;
    private final int refreshTtlDays;
    private final String dummyHash;

    public AuthService(UserRepository users, JdbcClient jdbc, PasswordEncoder encoder, JwtService jwt,
                       AuditService audit, ResetTokenSender resetSender, AppProperties props) {
        this.users = users;
        this.jdbc = jdbc;
        this.encoder = encoder;
        this.jwt = jwt;
        this.audit = audit;
        this.resetSender = resetSender;
        this.refreshTtlDays = props.jwt().refreshTtlDays();
        this.dummyHash = encoder.encode("not-a-real-password");
    }

    @Transactional
    public TokenPair registerPatient(String email, String password, String fullName, String phone, String deviceLabel) {
        String normalized = email.trim().toLowerCase();
        if (users.emailExists(normalized)) {
            throw ApiException.conflict("REGISTRATION_FAILED", "Unable to register with the provided details");
        }
        UUID userId;
        try {
            userId = users.insertUser(normalized, encoder.encode(password), fullName.trim(), phone, "PATIENT");
        } catch (org.springframework.dao.DuplicateKeyException e) {
            throw ApiException.conflict("REGISTRATION_FAILED", "Unable to register with the provided details");
        }
        Instant now = Instant.now();
        jdbc.sql("INSERT INTO patient_profiles (id, user_id, created_at, updated_at) VALUES (:id, :u, :n, :n)")
                .param("id", UUID.randomUUID()).param("u", userId).param("n", Timestamp.from(now)).update();
        audit.record(null, "AUTH_REGISTER", "USER", userId, "SUCCESS", null);
        return issueTokens(userId, UUID.randomUUID(), deviceLabel);
    }

    public TokenPair login(String email, String password, String deviceLabel) {
        Optional<UserRow> found = users.findByEmail(email.trim().toLowerCase());
        // Always run one hash verification so response time does not reveal whether the account exists.
        String hash = found.map(UserRow::passwordHash).orElse(dummyHash);
        boolean matches = encoder.matches(password, hash);
        UserRow user = found.orElse(null);
        if (user == null || !"ACTIVE".equals(user.status())) {
            audit.record(null, "AUTH_LOGIN", "USER", null, "FAILURE", "unknown or inactive account");
            throw invalidCredentials();
        }
        if (user.lockedUntil() != null && user.lockedUntil().isAfter(Instant.now())) {
            audit.record(null, "AUTH_LOGIN", "USER", user.id(), "DENIED", "account temporarily locked");
            throw invalidCredentials();
        }
        if (!matches) {
            int failures = user.failedLogins() + 1;
            Instant lock = failures >= MAX_FAILED_LOGINS ? Instant.now().plus(15, ChronoUnit.MINUTES) : null;
            users.recordFailedLogin(user.id(), failures, lock);
            audit.record(null, "AUTH_LOGIN", "USER", user.id(), "FAILURE", "bad credentials");
            throw invalidCredentials();
        }
        users.clearFailedLogins(user.id());
        audit.record(null, "AUTH_LOGIN", "USER", user.id(), "SUCCESS", null);
        return issueTokens(user.id(), UUID.randomUUID(), deviceLabel);
    }

    /** Rotates the refresh token. Presenting an already-used token revokes the whole token family. */
    @Transactional(noRollbackFor = ApiException.class) // family revocation must persist when reuse is detected
    public TokenPair refresh(String refreshToken) {
        String hash = sha256(refreshToken);
        var row = jdbc.sql("""
                SELECT id, user_id, family_id, expires_at, revoked_at, device_label
                FROM refresh_token_sessions WHERE token_hash = :h""").param("h", hash)
                .query((rs, n) -> new Object[]{rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                        rs.getObject("family_id", UUID.class), rs.getTimestamp("expires_at").toInstant(),
                        rs.getTimestamp("revoked_at"), rs.getString("device_label")})
                .optional();
        if (row.isEmpty()) throw ApiException.unauthorized("Session expired. Please sign in again.");
        Object[] r = row.get();
        UUID sessionId = (UUID) r[0], userId = (UUID) r[1], family = (UUID) r[2];
        Instant expires = (Instant) r[3];
        if (r[4] != null) {
            revokeFamily(family);
            audit.record(null, "AUTH_REFRESH_REUSE", "USER", userId, "DENIED", "revoked token presented; family revoked");
            throw ApiException.unauthorized("Session expired. Please sign in again.");
        }
        if (expires.isBefore(Instant.now())) throw ApiException.unauthorized("Session expired. Please sign in again.");
        // Atomic claim: only one concurrent caller can flip revoked_at from NULL.
        int claimed = jdbc.sql("UPDATE refresh_token_sessions SET revoked_at = :now WHERE id = :id AND revoked_at IS NULL")
                .param("now", Timestamp.from(Instant.now())).param("id", sessionId).update();
        if (claimed != 1) {
            revokeFamily(family);
            throw ApiException.unauthorized("Session expired. Please sign in again.");
        }
        if (users.loadPrincipal(userId).isEmpty()) throw ApiException.unauthorized("Session expired. Please sign in again.");
        return issueTokens(userId, family, (String) r[5]);
    }

    @Transactional
    public void logout(String refreshToken) {
        jdbc.sql("""
                UPDATE refresh_token_sessions SET revoked_at = :now
                WHERE family_id IN (SELECT family_id FROM refresh_token_sessions WHERE token_hash = :h)
                  AND revoked_at IS NULL""")
                .param("now", Timestamp.from(Instant.now())).param("h", sha256(refreshToken)).update();
    }

    @Transactional
    public void requestPasswordReset(String email) {
        users.findByEmail(email.trim().toLowerCase()).ifPresent(u -> {
            byte[] raw = new byte[32];
            RANDOM.nextBytes(raw);
            String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
            Instant now = Instant.now();
            jdbc.sql("""
                    INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at, created_at)
                    VALUES (:id, :u, :h, :exp, :now)""")
                    .param("id", UUID.randomUUID()).param("u", u.id()).param("h", sha256(token))
                    .param("exp", Timestamp.from(now.plus(30, ChronoUnit.MINUTES)))
                    .param("now", Timestamp.from(now)).update();
            resetSender.send(u.email(), token);
            audit.record(null, "AUTH_PASSWORD_RESET_REQUEST", "USER", u.id(), "SUCCESS", null);
        });
    }

    @Transactional
    public void confirmPasswordReset(String token, String newPassword) {
        var row = jdbc.sql("""
                SELECT id, user_id, expires_at, used_at FROM password_reset_tokens WHERE token_hash = :h""")
                .param("h", sha256(token))
                .query((rs, n) -> new Object[]{rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                        rs.getTimestamp("expires_at").toInstant(), rs.getTimestamp("used_at")})
                .optional();
        if (row.isEmpty() || row.get()[3] != null || ((Instant) row.get()[2]).isBefore(Instant.now())) {
            throw ApiException.badRequest("INVALID_RESET_TOKEN", "This reset link is invalid or has expired");
        }
        UUID userId = (UUID) row.get()[1];
        int used = jdbc.sql("UPDATE password_reset_tokens SET used_at = :now WHERE id = :id AND used_at IS NULL")
                .param("now", Timestamp.from(Instant.now())).param("id", row.get()[0]).update();
        if (used != 1) throw ApiException.badRequest("INVALID_RESET_TOKEN", "This reset link is invalid or has expired");
        users.updatePassword(userId, encoder.encode(newPassword));
        users.revokeAllSessions(userId);
        audit.record(null, "AUTH_PASSWORD_RESET", "USER", userId, "SUCCESS", null);
    }

    private TokenPair issueTokens(UUID userId, UUID family, String deviceLabel) {
        byte[] raw = new byte[48];
        RANDOM.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        Instant now = Instant.now();
        jdbc.sql("""
                INSERT INTO refresh_token_sessions (id, user_id, family_id, token_hash, device_label, expires_at, created_at)
                VALUES (:id, :u, :f, :h, :d, :exp, :now)""")
                .param("id", UUID.randomUUID()).param("u", userId).param("f", family).param("h", sha256(refresh))
                .param("d", deviceLabel).param("exp", Timestamp.from(now.plus(refreshTtlDays, ChronoUnit.DAYS)))
                .param("now", Timestamp.from(now)).update();
        return new TokenPair(jwt.issue(userId), refresh, jwt.accessTtlSeconds());
    }

    private void revokeFamily(UUID family) {
        jdbc.sql("UPDATE refresh_token_sessions SET revoked_at = :now WHERE family_id = :f AND revoked_at IS NULL")
                .param("now", Timestamp.from(Instant.now())).param("f", family).update();
    }

    private static ApiException invalidCredentials() {
        return ApiException.unauthorized("Invalid email or password");
    }

    static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}

package com.healthresponse.platform.common;

import com.healthresponse.platform.security.AuthPrincipal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Append-only audit trail. Runs in its own transaction so that denied or failed operations are still recorded.
 * Never pass medical content or secrets in {@code detail}.
 */
@Service
public class AuditService {
    private final JdbcClient jdbc;

    public AuditService(JdbcClient jdbc) { this.jdbc = jdbc; }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(AuthPrincipal actor, String action, String targetType, Object targetId, String outcome, String detail) {
        jdbc.sql("""
                INSERT INTO audit_logs (id, actor_id, actor_role, action, target_type, target_id, outcome, detail, created_at)
                VALUES (:id, :actor, :role, :action, :tt, :tid, :outcome, :detail, :now)""")
                .param("id", UUID.randomUUID())
                .param("actor", actor == null ? null : actor.userId())
                .param("role", actor == null ? null : actor.primaryRole())
                .param("action", action).param("tt", targetType)
                .param("tid", targetId == null ? null : targetId.toString())
                .param("outcome", outcome).param("detail", detail)
                .param("now", Timestamp.from(Instant.now())).update();
    }

    public void ok(AuthPrincipal actor, String action, String targetType, Object targetId) {
        record(actor, action, targetType, targetId, "SUCCESS", null);
    }

    public void denied(AuthPrincipal actor, String action, String targetType, Object targetId) {
        record(actor, action, targetType, targetId, "DENIED", null);
    }
}

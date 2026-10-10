package com.healthresponse.platform.notification;

import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.security.AppProperties;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Outbox processor for push delivery. Honest outcomes only:
 *  - FCM not configured  -> NOT_CONFIGURED (the in-app inbox entry still exists, nothing is claimed as pushed)
 *  - transient failure   -> retried with exponential backoff, then FAILED
 * A real FCM client must implement {@link PushGateway}; none is bundled because no Firebase credentials exist here.
 */
@Component
public class NotificationDispatcher {
    private static final Logger log = LoggerFactory.getLogger(NotificationDispatcher.class);
    static final int MAX_ATTEMPTS = 5;

    /** Boundary for a real push provider. */
    public interface PushGateway {
        boolean isConfigured();
        /** @throws Exception on transient delivery failure */
        void send(String deviceToken, String title, String body) throws Exception;
    }

    private record Pending(UUID attemptId, UUID userId, String title, String body, int attempts) {}

    private final JdbcClient jdbc;
    private final PushGateway gateway;

    public NotificationDispatcher(JdbcClient jdbc, AppProperties props, java.util.Optional<PushGateway> gateway) {
        this.jdbc = jdbc;
        this.gateway = gateway.orElse(new PushGateway() {
            public boolean isConfigured() { return false; }
            public void send(String t, String ti, String b) { throw new UnsupportedOperationException(); }
        });
    }

    @Scheduled(fixedDelay = 5000)
    public void dispatchDue() { dispatchDue(Instant.now()); }

    /** Package-visible for tests. */
    public int dispatchDue(Instant now) {
        List<Pending> due = jdbc.sql("""
                SELECT a.id, n.user_id, n.title, n.body, a.attempts
                FROM notification_delivery_attempts a JOIN notifications n ON n.id = a.notification_id
                WHERE a.status = 'PENDING' AND a.next_attempt_at <= :now ORDER BY a.created_at LIMIT 50""")
                .param("now", Sql.ts(now))
                .query((rs, i) -> new Pending(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                        rs.getString("title"), rs.getString("body"), rs.getInt("attempts")))
                .list();
        for (Pending p : due) deliver(p, now);
        return due.size();
    }

    private void deliver(Pending p, Instant now) {
        if (!gateway.isConfigured()) {
            update(p.attemptId(), "NOT_CONFIGURED", p.attempts(), null, "Push provider not configured", now);
            return;
        }
        List<String> tokens = jdbc.sql("SELECT token FROM device_tokens WHERE user_id = :u").param("u", p.userId())
                .query(String.class).list();
        if (tokens.isEmpty()) {
            update(p.attemptId(), "FAILED", p.attempts() + 1, null, "No registered device", now);
            return;
        }
        try {
            for (String t : tokens) gateway.send(t, p.title(), p.body());
            update(p.attemptId(), "SENT", p.attempts() + 1, null, null, now);
        } catch (Exception e) {
            int attempts = p.attempts() + 1;
            log.warn("Push delivery attempt {} failed for {}: {}", attempts, p.attemptId(), e.getClass().getSimpleName() + " " + e.getMessage());
            if (attempts >= MAX_ATTEMPTS) {
                update(p.attemptId(), "FAILED", attempts, null, "Delivery failed after retries", now);
            } else {
                Instant next = now.plusSeconds((long) Math.pow(2, attempts) * 10);
                update(p.attemptId(), "PENDING", attempts, next, "Transient failure", now);
            }
        }
    }

    private void update(UUID id, String status, int attempts, Instant next, String error, Instant now) {
        jdbc.sql("""
                UPDATE notification_delivery_attempts
                SET status = :s, attempts = :a, next_attempt_at = :n, last_error = :e, updated_at = :now WHERE id = :id""")
                .param("s", status).param("a", attempts).param("n", Sql.ts(next)).param("e", error)
                .param("now", Sql.ts(now)).param("id", id).update();
    }
}

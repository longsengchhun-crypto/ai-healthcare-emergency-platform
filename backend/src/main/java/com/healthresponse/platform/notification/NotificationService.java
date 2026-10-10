package com.healthresponse.platform.notification;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.Sql;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Creating a notification is separate from delivering it. {@link #create} persists the notification (visible in the
 * in-app inbox) plus a PENDING push delivery attempt that {@link NotificationDispatcher} processes with retries.
 * Notification text must never contain medical details.
 */
@Service
public class NotificationService {
    public record NotificationView(UUID id, String category, String title, String body, String refType, UUID refId,
                                   boolean read, Instant createdAt) {}

    private final JdbcClient jdbc;

    public NotificationService(JdbcClient jdbc) { this.jdbc = jdbc; }

    @Transactional
    public UUID create(UUID userId, String category, String title, String body, String refType, UUID refId) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        jdbc.sql("""
                INSERT INTO notifications (id, user_id, category, title, body, ref_type, ref_id, created_at)
                VALUES (:id, :u, :c, :t, :b, :rt, :ri, :now)""")
                .param("id", id).param("u", userId).param("c", category).param("t", title).param("b", body)
                .param("rt", refType).param("ri", refId).param("now", Sql.ts(now)).update();
        jdbc.sql("""
                INSERT INTO notification_delivery_attempts
                  (id, notification_id, channel, status, attempts, next_attempt_at, created_at, updated_at)
                VALUES (:id, :n, 'PUSH', 'PENDING', 0, :now, :now, :now)""")
                .param("id", UUID.randomUUID()).param("n", id).param("now", Sql.ts(now)).update();
        return id;
    }

    public List<NotificationView> list(UUID userId, int limit) {
        return jdbc.sql("""
                SELECT id, category, title, body, ref_type, ref_id, read_at, created_at
                FROM notifications WHERE user_id = :u ORDER BY created_at DESC LIMIT :l""")
                .param("u", userId).param("l", Math.min(Math.max(limit, 1), 100))
                .query((rs, n) -> new NotificationView(rs.getObject("id", UUID.class), rs.getString("category"),
                        rs.getString("title"), rs.getString("body"), rs.getString("ref_type"),
                        rs.getObject("ref_id", UUID.class), rs.getTimestamp("read_at") != null,
                        Sql.instant(rs, "created_at")))
                .list();
    }

    public int unreadCount(UUID userId) {
        return jdbc.sql("SELECT COUNT(*) FROM notifications WHERE user_id = :u AND read_at IS NULL")
                .param("u", userId).query(Integer.class).single();
    }

    @Transactional
    public void markRead(UUID userId, UUID id) {
        int n = jdbc.sql("UPDATE notifications SET read_at = COALESCE(read_at, :now) WHERE id = :id AND user_id = :u")
                .param("now", Sql.ts(Instant.now())).param("id", id).param("u", userId).update();
        if (n == 0) throw ApiException.notFound("Notification");
    }

    @Transactional
    public UUID registerDevice(UUID userId, String token, String platform) {
        jdbc.sql("DELETE FROM device_tokens WHERE token = :t").param("t", token).update();
        UUID id = UUID.randomUUID();
        jdbc.sql("INSERT INTO device_tokens (id, user_id, token, platform, created_at) VALUES (:id, :u, :t, :p, :now)")
                .param("id", id).param("u", userId).param("t", token).param("p", platform)
                .param("now", Sql.ts(Instant.now())).update();
        return id;
    }

    @Transactional
    public void removeDevice(UUID userId, UUID id) {
        int n = jdbc.sql("DELETE FROM device_tokens WHERE id = :id AND user_id = :u").param("id", id).param("u", userId).update();
        if (n == 0) throw ApiException.notFound("Device");
    }
}

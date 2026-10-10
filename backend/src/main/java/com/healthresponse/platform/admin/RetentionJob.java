package com.healthresponse.platform.admin;

import com.healthresponse.platform.common.Sql;
import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Data-minimisation job. Defaults: emergency locations of finished events 90 days, sensor evidence 30 days,
 * expired/revoked sessions 30 days, used/expired reset tokens 7 days. Configure with RETENTION_* env vars.
 * Audit logs and emergency history are intentionally kept.
 */
@Component
public class RetentionJob {
    private static final Logger log = LoggerFactory.getLogger(RetentionJob.class);
    private final JdbcClient jdbc;
    private final int locationDays;
    private final int sensorDays;
    private final int sessionDays;

    public RetentionJob(JdbcClient jdbc,
                        @Value("${RETENTION_LOCATION_DAYS:90}") int locationDays,
                        @Value("${RETENTION_SENSOR_DAYS:30}") int sensorDays,
                        @Value("${RETENTION_SESSION_DAYS:30}") int sessionDays) {
        this.jdbc = jdbc;
        this.locationDays = locationDays;
        this.sensorDays = sensorDays;
        this.sessionDays = sessionDays;
    }

    @Scheduled(cron = "0 30 3 * * *")
    public void scheduled() { run(Instant.now()); }

    /** Returns the number of rows removed (for tests). */
    public int run(Instant now) {
        int n = 0;
        n += jdbc.sql("""
                DELETE FROM emergency_event_locations WHERE captured_at < :cut AND event_id IN
                  (SELECT id FROM emergency_events WHERE status IN ('RESOLVED','CANCELLED','REJECTED','FAILED'))""")
                .param("cut", Sql.ts(now.minus(Duration.ofDays(locationDays)))).update();
        n += jdbc.sql("DELETE FROM sensor_readings WHERE recorded_at < :cut")
                .param("cut", Sql.ts(now.minus(Duration.ofDays(sensorDays)))).update();
        Instant sessionCut = now.minus(Duration.ofDays(sessionDays));
        n += jdbc.sql("DELETE FROM refresh_token_sessions WHERE expires_at < :cut OR revoked_at < :cut")
                .param("cut", Sql.ts(sessionCut)).update();
        n += jdbc.sql("DELETE FROM password_reset_tokens WHERE expires_at < :cut")
                .param("cut", Sql.ts(now.minus(Duration.ofDays(7)))).update();
        if (n > 0) log.info("Retention removed {} rows", n);
        return n;
    }
}

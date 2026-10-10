package com.healthresponse.platform.notification;

import com.healthresponse.platform.common.Sql;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Alerts a patient's emergency contacts by SMS. Rules (all enforced here, not by the client):
 *  - never for demonstration events;
 *  - only if the patient's latest consent for EMERGENCY_CONTACT_SMS is granted;
 *  - only if an SMS provider is configured;
 *  - delivery is queued (outbox), retried with back-off, and each outcome is written to the event history.
 * The SMS says that the person asked for help and, if shared, includes a map link. No medical data is sent.
 */
@Service
public class ContactAlertService {
    private static final Logger log = LoggerFactory.getLogger(ContactAlertService.class);
    static final int MAX_ATTEMPTS = 4;
    public static final String CONSENT_PURPOSE = "EMERGENCY_CONTACT_SMS";

    private record Pending(UUID id, UUID eventId, String name, String phone, int attempts) {}

    private final JdbcClient jdbc;
    private final SmsSender sms;

    public ContactAlertService(JdbcClient jdbc, SmsSender sms) {
        this.jdbc = jdbc;
        this.sms = sms;
    }

    /** Queues alerts and returns the (honest) sentence to store in the emergency history. */
    public String queue(UUID eventId, UUID patientId, boolean demo) {
        if (demo) return "Demonstration event: emergency contacts were not alerted";
        boolean consent = Boolean.TRUE.equals(jdbc.sql("""
                SELECT c.granted FROM consent_records c JOIN patient_profiles p ON p.user_id = c.user_id
                WHERE p.id = :p AND c.purpose = :purpose ORDER BY c.created_at DESC LIMIT 1""")
                .param("p", patientId).param("purpose", CONSENT_PURPOSE).query(Boolean.class).optional().orElse(false));
        if (!consent) return "Emergency contacts NOT alerted: the patient has not enabled SMS alerts";
        List<Object[]> contacts = jdbc.sql("""
                SELECT id, name, phone FROM emergency_contacts WHERE patient_id = :p ORDER BY priority""")
                .param("p", patientId)
                .query((rs, n) -> new Object[]{rs.getObject("id", UUID.class), rs.getString("name"), rs.getString("phone")})
                .list();
        if (contacts.isEmpty()) return "No emergency contacts are configured";
        if (!sms.isConfigured()) return "Emergency contacts NOT alerted: no SMS provider is configured";
        Instant now = Instant.now();
        for (Object[] c : contacts) {
            jdbc.sql("""
                    INSERT INTO contact_alert_attempts (id, event_id, contact_id, contact_name, phone, status, attempts,
                                                        next_attempt_at, created_at, updated_at)
                    VALUES (:id, :e, :c, :n, :p, 'PENDING', 0, :now, :now, :now)""")
                    .param("id", UUID.randomUUID()).param("e", eventId).param("c", c[0]).param("n", c[1])
                    .param("p", c[2]).param("now", Sql.ts(now)).update();
        }
        return "SMS alerts queued for " + contacts.size() + " contact(s); delivery not yet confirmed";
    }

    @Scheduled(fixedDelay = 5000)
    public void dispatch() { dispatch(Instant.now()); }

    public int dispatch(Instant now) {
        List<Pending> due = jdbc.sql("""
                SELECT id, event_id, contact_name, phone, attempts FROM contact_alert_attempts
                WHERE status = 'PENDING' AND next_attempt_at <= :now ORDER BY created_at LIMIT 50""")
                .param("now", Sql.ts(now))
                .query((rs, n) -> new Pending(rs.getObject("id", UUID.class), rs.getObject("event_id", UUID.class),
                        rs.getString("contact_name"), rs.getString("phone"), rs.getInt("attempts"))).list();
        for (Pending p : due) deliver(p, now);
        return due.size();
    }

    private void deliver(Pending p, Instant now) {
        if (!sms.isConfigured()) {
            update(p, "NOT_CONFIGURED", p.attempts(), null, "SMS provider not configured", now);
            return;
        }
        try {
            sms.send(p.phone(), body(p.eventId()));
            update(p, "SENT", p.attempts() + 1, null, null, now);
            history(p, "SMS sent to " + p.name(), now);
        } catch (Exception e) {
            int attempts = p.attempts() + 1;
            log.warn("SMS attempt {} failed for alert {}", attempts, p.id());
            if (attempts >= MAX_ATTEMPTS) {
                update(p, "FAILED", attempts, null, "Delivery failed after retries", now);
                history(p, "SMS to " + p.name() + " FAILED after retries", now);
            } else {
                update(p, "PENDING", attempts, now.plusSeconds((long) Math.pow(2, attempts) * 15), "Transient failure", now);
            }
        }
    }

    private String body(UUID eventId) {
        var row = jdbc.sql("""
                SELECT u.full_name, l.latitude, l.longitude
                FROM emergency_events e JOIN patient_profiles pp ON pp.id = e.patient_id
                JOIN users u ON u.id = pp.user_id
                LEFT JOIN emergency_event_locations l ON l.event_id = e.id
                WHERE e.id = :id ORDER BY l.captured_at DESC LIMIT 1""").param("id", eventId)
                .query((rs, n) -> new Object[]{rs.getString("full_name"),
                        rs.getObject("latitude") == null ? null : rs.getDouble("latitude"),
                        rs.getObject("longitude") == null ? null : rs.getDouble("longitude")}).single();
        String text = row[0] + " asked for emergency help using HealthResponse.";
        if (row[1] != null) {
            text += " Last shared location: https://maps.google.com/?q=" + row[1] + "," + row[2];
        }
        return text + " Please try to contact them. If they are in danger call your local emergency number.";
    }

    private void history(Pending p, String note, Instant now) {
        jdbc.sql("""
                INSERT INTO emergency_event_history (id, event_id, from_status, to_status, actor_id, note, created_at)
                SELECT :id, e.id, e.status, e.status, NULL, :n, :now FROM emergency_events e WHERE e.id = :e""")
                .param("id", UUID.randomUUID()).param("n", note).param("now", Sql.ts(now)).param("e", p.eventId()).update();
    }

    private void update(Pending p, String status, int attempts, Instant next, String error, Instant now) {
        jdbc.sql("""
                UPDATE contact_alert_attempts SET status = :s, attempts = :a, next_attempt_at = :n, last_error = :e,
                       updated_at = :now WHERE id = :id""")
                .param("s", status).param("a", attempts).param("n", Sql.ts(next)).param("e", error)
                .param("now", Sql.ts(now)).param("id", p.id()).update();
    }
}

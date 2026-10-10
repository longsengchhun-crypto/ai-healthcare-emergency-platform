package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.admin.DemoDataSeeder;
import com.healthresponse.platform.notification.ContactAlertService;
import com.healthresponse.platform.notification.NotificationDispatcher;
import com.healthresponse.platform.notification.NotificationService;
import com.healthresponse.platform.notification.SmsSender;
import com.healthresponse.platform.notification.TwilioSmsSender;
import com.healthresponse.platform.security.AppProperties;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(NotificationChannelsTest.FakeSms.class)
class NotificationChannelsTest {
    static final String PW = "Demo-Password-123";

    /** Records messages instead of calling a provider. */
    static class RecordingSms implements SmsSender {
        final List<String> sent = new CopyOnWriteArrayList<>();
        volatile boolean fail;
        public boolean isConfigured() { return true; }
        public void send(String to, String body) throws Exception {
            if (fail) throw new java.io.IOException("provider down");
            sent.add(to + "|" + body);
        }
    }

    @TestConfiguration
    static class FakeSms {
        @Bean @Primary RecordingSms recordingSms() { return new RecordingSms(); }
    }

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired RecordingSms sms;
    @Autowired ContactAlertService alerts;
    @Autowired JdbcClient jdbc;
    @Autowired NotificationService notifications;
    @Autowired AppProperties props;

    String login(String email) throws Exception {
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    JsonNode call(MockHttpServletRequestBuilder b, String token, Object body, int expected) throws Exception {
        b.header("Authorization", "Bearer " + token);
        if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        String res = mvc.perform(b).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return res.isBlank() ? null : json.readTree(res);
    }

    String newPatient() throws Exception {
        String email = "n" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW, "fullName", "Alert Patient"))))
                .andExpect(status().isCreated());
        return login(email);
    }

    String historyText(String token, String eventId) throws Exception {
        return call(get("/api/v1/emergencies/" + eventId), token, null, 200).get("history").toString();
    }

    // ------------------------------------------------------------ SMS to emergency contacts

    @Test
    void contactsAreAlertedOnlyWithConsentAndNeverForDemoEvents() throws Exception {
        sms.sent.clear();
        sms.fail = false;
        String patient = newPatient();
        call(post("/api/v1/patients/me/emergency-contacts"), patient,
                Map.of("name", "Sok", "phone", "+85512345678"), 201);

        // 1. no consent: nothing queued, history says why
        JsonNode e1 = call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of("latitude", 11.5, "longitude", 104.9), 201);
        assertThat(historyText(patient, e1.get("id").asText())).contains("has not enabled SMS alerts");
        alerts.dispatch(Instant.now().plusSeconds(60));
        assertThat(sms.sent).isEmpty();

        // 2. consent granted but demo event: still nothing
        call(post("/api/v1/consents"), patient, Map.of("purpose", "EMERGENCY_CONTACT_SMS", "granted", true), 201);
        JsonNode e2 = call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of("demo", true), 201);
        assertThat(historyText(patient, e2.get("id").asText())).contains("Demonstration event");
        alerts.dispatch(Instant.now().plusSeconds(60));
        assertThat(sms.sent).isEmpty();

        // 3. consent + real event: queued, dispatched, outcome recorded
        JsonNode e3 = call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of("latitude", 11.5, "longitude", 104.9), 201);
        String id = e3.get("id").asText();
        assertThat(historyText(patient, id)).contains("SMS alerts queued for 1 contact");
        alerts.dispatch(Instant.now().plusSeconds(60));
        assertThat(sms.sent).hasSize(1);
        assertThat(sms.sent.get(0)).startsWith("+85512345678|").contains("Alert Patient")
                .contains("maps.google.com/?q=11.5,104.9");
        assertThat(historyText(patient, id)).contains("SMS sent to Sok");

        // 4. withdrawing consent stops future alerts
        call(post("/api/v1/consents"), patient, Map.of("purpose", "EMERGENCY_CONTACT_SMS", "granted", false), 201);
        JsonNode e4 = call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of(), 201);
        assertThat(historyText(patient, e4.get("id").asText())).contains("has not enabled SMS alerts");
    }

    @Test
    void failedSmsIsRetriedThenMarkedFailedAndNeverClaimedSent() throws Exception {
        sms.sent.clear();
        sms.fail = true;
        String patient = newPatient();
        call(post("/api/v1/patients/me/emergency-contacts"), patient, Map.of("name", "Dara", "phone", "+85598765432"), 201);
        call(post("/api/v1/consents"), patient, Map.of("purpose", "EMERGENCY_CONTACT_SMS", "granted", true), 201);
        JsonNode e = call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of(), 201);
        String id = e.get("id").asText();
        Instant t = Instant.now();
        for (int i = 0; i < 6; i++) {
            t = t.plusSeconds(3600);
            alerts.dispatch(t);
        }
        assertThat(sms.sent).isEmpty();
        String h = historyText(patient, id);
        assertThat(h).contains("FAILED after retries").doesNotContain("SMS sent to Dara");
        sms.fail = false;
    }

    // ------------------------------------------------------------ Twilio REST client

    @Test
    void twilioClientSendsAuthenticatedFormRequestAndSurfacesProviderErrors() throws Exception {
        AtomicReference<String> auth = new AtomicReference<>();
        AtomicReference<String> bodyRef = new AtomicReference<>();
        AtomicReference<String> pathRef = new AtomicReference<>();
        int[] statusCode = {201};
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            auth.set(ex.getRequestHeaders().getFirst("Authorization"));
            pathRef.set(ex.getRequestURI().getPath());
            bodyRef.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] out = "{}".getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(statusCode[0], out.length);
            ex.getResponseBody().write(out);
            ex.close();
        });
        server.start();
        try {
            String base = "http://127.0.0.1:" + server.getAddress().getPort();
            TwilioSmsSender sender = new TwilioSmsSender("ACtest", "secret-token", "+15005550006", base);
            assertThat(sender.isConfigured()).isTrue();
            sender.send("+85512345678", "hello & welcome");
            assertThat(auth.get()).isEqualTo("Basic " + java.util.Base64.getEncoder()
                    .encodeToString("ACtest:secret-token".getBytes(StandardCharsets.UTF_8)));
            assertThat(pathRef.get()).isEqualTo("/2010-04-01/Accounts/ACtest/Messages.json");
            assertThat(bodyRef.get()).contains("To=%2B85512345678").contains("From=%2B15005550006")
                    .contains("Body=hello+%26+welcome");
            statusCode[0] = 400;
            assertThatThrownBy(() -> sender.send("+85512345678", "x")).hasMessageContaining("HTTP 400");
        } finally {
            server.stop(0);
        }
        assertThat(new TwilioSmsSender("", "", "", "http://x").isConfigured()).isFalse();
    }

    // ------------------------------------------------------------ push outbox with a gateway

    @Test
    void pushOutboxDeliversRetriesAndFailsHonestly() throws Exception {
        UUID user = jdbc.sql("SELECT id FROM users WHERE email = :e").param("e", DemoDataSeeder.PATIENT)
                .query(UUID.class).single();
        notifications.registerDevice(user, "token-" + UUID.randomUUID(), "ANDROID");

        List<String> delivered = new ArrayList<>();
        boolean[] failing = {false};
        NotificationDispatcher.PushGateway gateway = new NotificationDispatcher.PushGateway() {
            public boolean isConfigured() { return true; }
            public void send(String token, String title, String body) throws Exception {
                if (failing[0]) throw new RuntimeException("fcm unavailable");
                delivered.add(title);
            }
        };
        NotificationDispatcher dispatcher = new NotificationDispatcher(jdbc, props, Optional.of(gateway));
        jdbc.sql("UPDATE notification_delivery_attempts SET status = 'SENT' WHERE status = 'PENDING'").update();

        // success path
        UUID ok = notifications.create(user, "TEST", "Hello", "Body", null, null);
        assertThat(dispatcher.dispatchDue(Instant.now().plusSeconds(5))).isEqualTo(1);
        assertThat(delivered).containsExactly("Hello");
        assertThat(statusOf(ok)).isEqualTo("SENT");

        // transient failure: stays PENDING with back-off, then FAILED after max attempts
        failing[0] = true;
        UUID bad = notifications.create(user, "TEST", "Will fail", "Body", null, null);
        Instant t = Instant.now();
        dispatcherRun(dispatcher, t.plusSeconds(5));
        assertThat(statusOf(bad)).isEqualTo("PENDING");
        for (int i = 1; i <= 6; i++) dispatcherRun(dispatcher, t.plusSeconds(100000L * i));
        assertThat(statusOf(bad)).isEqualTo("FAILED");

        // no gateway configured: honest NOT_CONFIGURED
        NotificationDispatcher none = new NotificationDispatcher(jdbc, props, Optional.empty());
        UUID nc = notifications.create(user, "TEST", "No gateway", "Body", null, null);
        none.dispatchDue(Instant.now().plusSeconds(5));
        assertThat(statusOf(nc)).isEqualTo("NOT_CONFIGURED");
    }

    private void dispatcherRun(NotificationDispatcher d, Instant at) { d.dispatchDue(at); }

    private String statusOf(UUID notificationId) {
        return jdbc.sql("SELECT status FROM notification_delivery_attempts WHERE notification_id = :n")
                .param("n", notificationId).query(String.class).single();
    }
}

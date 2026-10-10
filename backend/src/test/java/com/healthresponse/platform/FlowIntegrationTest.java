package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.admin.DemoDataSeeder;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FlowIntegrationTest {
    static final String PW = "Demo-Password-123";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    // ---- helpers
    String login(String email, String password) throws Exception {
        String body = json.writeValueAsString(Map.of("email", email, "password", password));
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    String registerPatient() throws Exception {
        String email = "x" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW, "fullName", "Extra Patient"))))
                .andExpect(status().isCreated());
        return login(email, PW);
    }

    JsonNode send(MockHttpServletRequestBuilder b, String token, Object body, int expected) throws Exception {
        b.header("Authorization", "Bearer " + token);
        if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        String res = mvc.perform(b).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return res.isBlank() ? null : json.readTree(res);
    }

    JsonNode getJson(String url, String token, int expected) throws Exception { return send(get(url), token, null, expected); }
    JsonNode postJson(String url, String token, Object body, int expected) throws Exception { return send(post(url), token, body, expected); }

    String firstDoctorId(String token) throws Exception {
        for (JsonNode d : getJson("/api/v1/doctors?q=Cardiologist", token, 200).get("items")) return d.get("id").asText();
        throw new AssertionError("no seeded doctor");
    }

    String firstFreeSlot(String doctorId, String token, int skip) throws Exception {
        int seen = 0;
        for (int i = 1; i < 14; i++) {
            JsonNode slots = getJson("/api/v1/doctors/" + doctorId + "/slots?date=" + LocalDate.now().plusDays(i), token, 200);
            for (JsonNode s : slots) if (seen++ == skip) return s.get("startsAt").asText();
        }
        throw new AssertionError("no free slot");
    }

    // ---- appointment flow
    @Test
    void appointmentBookingConfirmationAndDoubleBookingGuard() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT, PW);
        String doctor = login(DemoDataSeeder.DOCTOR, PW);
        String other = registerPatient();
        String doctorId = firstDoctorId(patient);
        String slot = firstFreeSlot(doctorId, patient, 3);

        JsonNode appt = postJson("/api/v1/appointments", patient,
                Map.of("doctorId", doctorId, "startsAt", slot, "reason", "Checkup"), 201);
        assertThat(appt.get("status").asText()).isEqualTo("REQUESTED");
        String id = appt.get("id").asText();

        // same slot again -> conflict (database-level uniqueness)
        postJson("/api/v1/appointments", other, Map.of("doctorId", doctorId, "startsAt", slot), 409);
        // another patient cannot read it (404, not 403, so ids cannot be probed)
        getJson("/api/v1/appointments/" + id, other, 404);
        // patient cannot confirm their own appointment
        postJson("/api/v1/appointments/" + id + "/confirm", patient, null, 403);
        // doctor confirms
        assertThat(postJson("/api/v1/appointments/" + id + "/confirm", doctor, null, 200).get("status").asText())
                .isEqualTo("CONFIRMED");
        // confirming twice is an invalid transition
        postJson("/api/v1/appointments/" + id + "/confirm", doctor, null, 409);
        // patient sees updated status and a notification
        assertThat(getJson("/api/v1/appointments/" + id, patient, 200).get("status").asText()).isEqualTo("CONFIRMED");
        assertThat(getJson("/api/v1/notifications", patient, 200).get("unread").asInt()).isGreaterThan(0);
        // cancel frees the slot for another patient
        postJson("/api/v1/appointments/" + id + "/cancel", patient, null, 200);
        postJson("/api/v1/appointments", other, Map.of("doctorId", doctorId, "startsAt", slot), 201);
    }

    @Test
    void clientCannotInjectStatusIntoAppointment() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT, PW);
        String doctorId = firstDoctorId(patient);
        String slot = firstFreeSlot(doctorId, patient, 8);
        JsonNode appt = postJson("/api/v1/appointments", patient,
                Map.of("doctorId", doctorId, "startsAt", slot, "status", "CONFIRMED"), 201);
        assertThat(appt.get("status").asText()).isEqualTo("REQUESTED");
    }

    // ---- emergency flow
    @Test
    void emergencyLifecycleWithIdempotencyAndAuthorization() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT, PW);
        String staff = login(DemoDataSeeder.STAFF, PW);
        String doctor = login(DemoDataSeeder.DOCTOR, PW);
        String stranger = registerPatient();
        String key = UUID.randomUUID().toString();

        MockHttpServletRequestBuilder create = post("/api/v1/emergencies").header("Idempotency-Key", key);
        JsonNode created = send(create, patient, Map.of("demo", true, "latitude", 11.56, "longitude", 104.93), 201);
        String id = created.get("id").asText();
        assertThat(created.get("status").asText()).isEqualTo("SUBMITTED");
        assertThat(created.get("disclaimer").asText()).contains("not a real emergency dispatch");

        // network retry with same key must not create a second event
        JsonNode retry = send(post("/api/v1/emergencies").header("Idempotency-Key", key), patient,
                Map.of("demo", true, "latitude", 11.56, "longitude", 104.93), 201);
        assertThat(retry.get("id").asText()).isEqualTo(id);
        assertThat(retry.get("duplicateRequest").asBoolean()).isTrue();

        // missing idempotency key is rejected
        postJson("/api/v1/emergencies", patient, Map.of("demo", true), 400);

        // authorization boundaries
        getJson("/api/v1/emergencies/" + id, stranger, 404);
        postJson("/api/v1/emergencies/" + id + "/acknowledge", patient, null, 403);
        postJson("/api/v1/emergencies/" + id + "/acknowledge", doctor, null, 403);

        // staff sees it in the queue and works it
        assertThat(getJson("/api/v1/emergencies?status=SUBMITTED", staff, 200).toString()).contains(id);
        // cannot skip states
        postJson("/api/v1/emergencies/" + id + "/status", staff, Map.of("status", "RESOLVED"), 409);
        assertThat(postJson("/api/v1/emergencies/" + id + "/acknowledge", staff, null, 200).get("status").asText())
                .isEqualTo("ACKNOWLEDGED");
        String doctorUserId = getJson("/api/v1/users/me", doctor, 200).get("id").asText();
        assertThat(postJson("/api/v1/emergencies/" + id + "/assign", staff, Map.of("responderId", doctorUserId), 200)
                .get("status").asText()).isEqualTo("RESPONDER_ASSIGNED");
        for (String next : new String[]{"RESPONDER_EN_ROUTE", "ARRIVED", "RESOLVED"}) {
            assertThat(postJson("/api/v1/emergencies/" + id + "/status", staff, Map.of("status", next), 200)
                    .get("status").asText()).isEqualTo(next);
        }
        // terminal: cannot cancel a resolved event
        postJson("/api/v1/emergencies/" + id + "/cancel", patient, null, 409);

        JsonNode finalView = getJson("/api/v1/emergencies/" + id, patient, 200);
        assertThat(finalView.get("history").size()).isGreaterThanOrEqualTo(7);
        // patient view must not expose responder-only identity fields
        assertThat(finalView.has("patientName")).isFalse();
    }

    @Test
    void patientCanCancelFalseAlarmBeforeArrival() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT, PW);
        JsonNode created = send(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()),
                patient, Map.of("demo", true), 201);
        String id = created.get("id").asText();
        assertThat(postJson("/api/v1/emergencies/" + id + "/cancel", patient, Map.of("note", "false alarm"), 200)
                .get("status").asText()).isEqualTo("CANCELLED");
    }
}

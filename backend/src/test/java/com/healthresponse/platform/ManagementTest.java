package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.admin.DemoDataSeeder;
import com.healthresponse.platform.admin.RetentionJob;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ManagementTest {
    static final String PW = "Demo-Password-123";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired RetentionJob retention;

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

    @Test
    void hospitalAndDepartmentManagementRequiresPermission() throws Exception {
        String staff = login(DemoDataSeeder.STAFF);
        String patient = login(DemoDataSeeder.PATIENT);
        call(post("/api/v1/admin/hospitals"), patient, Map.of("name", "X"), 403);
        String id = call(post("/api/v1/admin/hospitals"), staff,
                Map.of("name", "New Clinic", "city", "Battambang", "latitude", 13.1, "longitude", 103.2), 201)
                .get("id").asText();
        call(post("/api/v1/admin/hospitals/" + id + "/departments"), staff, Map.of("name", "Pediatrics"), 201);
        JsonNode h = call(get("/api/v1/hospitals/" + id), patient, null, 200);
        assertThat(h.get("departments").toString()).contains("Pediatrics");
        call(post("/api/v1/admin/hospitals"), staff, Map.of("name", "", "latitude", 999), 422);
    }

    @Test
    void doctorManagesOwnAvailabilityAndPatientCannot() throws Exception {
        String doctor = login(DemoDataSeeder.DOCTOR2);
        String patient = login(DemoDataSeeder.PATIENT);
        call(put("/api/v1/doctors/me/availability"), patient, Map.of("windows", List.of()), 403);
        call(put("/api/v1/doctors/me/availability"), doctor, Map.of("windows", List.of(
                Map.of("dayOfWeek", 2, "startTime", "14:00:00", "endTime", "16:00:00", "slotMinutes", 20))), 200);
        JsonNode mine = call(get("/api/v1/doctors/me/availability"), doctor, null, 200);
        assertThat(mine.size()).isEqualTo(1);
        call(put("/api/v1/doctors/me/availability"), doctor, Map.of("windows", List.of(
                Map.of("dayOfWeek", 2, "startTime", "16:00:00", "endTime", "14:00:00"))), 400);
        call(patch("/api/v1/doctors/me"), doctor, Map.of("bio", "Updated bio"), 200);
    }

    @Test
    void adminListsDoctorsAndConsentIsRecorded() throws Exception {
        String admin = login(DemoDataSeeder.ADMIN);
        String patient = login(DemoDataSeeder.PATIENT);
        assertThat(call(get("/api/v1/admin/doctors"), admin, null, 200).size()).isGreaterThanOrEqualTo(2);
        call(get("/api/v1/admin/doctors"), patient, null, 403);
        call(post("/api/v1/consents"), patient, Map.of("purpose", "SENSOR_MONITORING", "granted", true), 201);
        call(post("/api/v1/consents"), patient, Map.of("purpose", "SENSOR_MONITORING", "granted", false), 201);
        assertThat(call(get("/api/v1/consents"), patient, null, 200).get("SENSOR_MONITORING").asBoolean()).isFalse();
    }

    @Test
    void retentionKeepsLocationOfActiveEvents() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT);
        call(post("/api/v1/emergencies").header("Idempotency-Key", UUID.randomUUID().toString()), patient,
                Map.of("demo", true, "latitude", 11.5, "longitude", 104.9), 201);
        retention.run(Instant.now().plusSeconds(400L * 86400));
        assertThat(call(get("/api/v1/emergencies"), patient, null, 200).toString()).contains("location");
    }
}

package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.admin.DemoDataSeeder;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
class VitalsIntegrationTest {
    static final String PW = "Demo-Password-123";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    String newPatient() throws Exception {
        String email = "v" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW, "fullName", "V"))))
                .andExpect(status().isCreated());
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
    void recordsClassifiesSummarisesAndDeletesMeasurements() throws Exception {
        String t = newPatient();
        JsonNode normal = call(post("/api/v1/vitals"), t,
                Map.of("type", "BLOOD_PRESSURE", "value1", 118, "value2", 76), 201);
        assertThat(normal.get("level").asText()).isEqualTo("NORMAL");
        assertThat(normal.get("unit").asText()).isEqualTo("mmHg");

        JsonNode high = call(post("/api/v1/vitals"), t,
                Map.of("type", "BLOOD_PRESSURE", "value1", 150, "value2", 95), 201);
        assertThat(high.get("level").asText()).isEqualTo("ATTENTION");
        JsonNode urgent = call(post("/api/v1/vitals"), t,
                Map.of("type", "OXYGEN_SATURATION", "value1", 86), 201);
        assertThat(urgent.get("level").asText()).isEqualTo("URGENT");
        JsonNode weight = call(post("/api/v1/vitals"), t, Map.of("type", "WEIGHT", "value1", 62.5), 201);
        assertThat(weight.get("level").asText()).isEqualTo("RECORDED");

        JsonNode bp = call(get("/api/v1/vitals?type=BLOOD_PRESSURE"), t, null, 200);
        assertThat(bp).hasSize(2);
        JsonNode summary = call(get("/api/v1/vitals/summary"), t, null, 200);
        assertThat(summary).hasSize(6);
        JsonNode bpSummary = summary.get(0);
        assertThat(bpSummary.get("type").asText()).isEqualTo("BLOOD_PRESSURE");
        assertThat(bpSummary.get("count30d").asLong()).isEqualTo(2);

        call(delete("/api/v1/vitals/" + high.get("id").asText()), t, null, 204);
        assertThat(call(get("/api/v1/vitals?type=BLOOD_PRESSURE"), t, null, 200)).hasSize(1);
    }

    @Test
    void rejectsImpossibleValuesFutureTimesAndUnknownTypes() throws Exception {
        String t = newPatient();
        call(post("/api/v1/vitals"), t, Map.of("type", "BLOOD_PRESSURE", "value1", 80, "value2", 120), 400);
        call(post("/api/v1/vitals"), t, Map.of("type", "BLOOD_PRESSURE", "value1", 120), 400);
        call(post("/api/v1/vitals"), t, Map.of("type", "HEART_RATE", "value1", 900), 400);
        call(post("/api/v1/vitals"), t, Map.of("type", "TEMPERATURE", "value1", 98.6), 400); // Fahrenheit typed as C
        call(post("/api/v1/vitals"), t, Map.of("type", "MAGIC", "value1", 1), 400);
        call(post("/api/v1/vitals"), t, Map.of("type", "HEART_RATE", "value1", 70,
                "measuredAt", Instant.now().plus(2, ChronoUnit.DAYS).toString()), 400);
    }

    @Test
    void measurementsAreStrictlyPrivate() throws Exception {
        String owner = newPatient();
        String other = newPatient();
        JsonNode v = call(post("/api/v1/vitals"), owner, Map.of("type", "HEART_RATE", "value1", 72), 201);
        assertThat(call(get("/api/v1/vitals"), other, null, 200)).isEmpty();
        call(delete("/api/v1/vitals/" + v.get("id").asText()), other, null, 404);
        // a doctor account has no patient profile of its own measurements and no access to others'
        String doctor = json.readTree(mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", DemoDataSeeder.DOCTOR, "password", PW))))
                .andReturn().getResponse().getContentAsString()).path("accessToken").asText();
        if (!doctor.isBlank()) call(get("/api/v1/vitals"), doctor, null, 403);
        mvc.perform(get("/api/v1/vitals")).andExpect(status().isUnauthorized());
    }
}

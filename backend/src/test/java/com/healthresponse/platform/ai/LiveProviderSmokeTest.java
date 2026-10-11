package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Opt-in smoke test against the REAL provider. Skipped unless AI_LIVE_PROVIDER and AI_LIVE_KEY are set in the
 * environment of the test run (the key is never written to a file). Uses fictional data only. Not part of CI.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class LiveProviderSmokeTest {
    static final String PROVIDER = System.getenv("AI_LIVE_PROVIDER");
    static final String KEY = System.getenv("AI_LIVE_KEY");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("app.ai.provider", () -> PROVIDER == null ? "deterministic-demo" : PROVIDER);
        r.add("app.ai.api-key", () -> KEY == null ? "" : KEY);
    }

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @BeforeAll
    static void only() { assumeTrue(PROVIDER != null && KEY != null, "live provider env not set"); }

    String patient() throws Exception {
        String email = "live" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Demo-Password-123", "fullName", "P"))))
                .andExpect(status().isCreated());
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Demo-Password-123"))))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    JsonNode call(String t, String path, Object body) throws Exception {
        String res = mvc.perform(post(path).header("Authorization", "Bearer " + t)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(res);
    }

    @Test
    void liveTriageSummaryAndTextExtraction() throws Exception {
        String t = patient();

        JsonNode neg = call(t, "/api/v1/ai/triage",
                Map.of("symptoms", "I have had a mild cough for two days. I have no chest pain and no trouble breathing."));
        System.out.println("LIVE triage(negation): " + neg.get("urgency") + " by=" + neg.get("assessedBy")
                + " status=" + neg.get("aiStatus") + " model=" + neg.get("languageModel"));
        System.out.println("  reasons=" + neg.get("reasons"));
        System.out.println("  nextSteps=" + neg.get("nextSteps"));
        System.out.println("  uncertainty=" + neg.get("uncertainty"));
        assertThat(neg.get("aiStatus").asText()).isEqualTo("OK");
        assertThat(neg.get("assessedBy").asText()).isEqualTo("RULES+AI");
        assertThat(neg.get("urgency").asText()).isNotEqualTo("EMERGENCY");

        JsonNode emergency = call(t, "/api/v1/ai/triage", Map.of("symptoms", "crushing chest pain spreading to my arm"));
        assertThat(emergency.get("urgency").asText()).isEqualTo("EMERGENCY");
        assertThat(emergency.get("aiStatus").asText()).isEqualTo("SKIPPED_EMERGENCY");

        JsonNode ambiguous = call(t, "/api/v1/ai/triage",
                Map.of("symptoms", "I feel off and dizzy since this morning and my vision is a bit blurry"));
        System.out.println("LIVE triage(ambiguous): " + ambiguous.get("urgency") + " status=" + ambiguous.get("aiStatus")
                + " uncertainty=" + ambiguous.get("uncertainty"));

        // summary with a fictional record
        mvc.perform(post("/api/v1/medical-records").header("Authorization", "Bearer " + t)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of(
                        "recordType", "HISTORY", "title", "Clinic note",
                        "body", "Allergy: penicillin\nMedication: Metformin 500mg twice daily\n"
                                + "Diagnosis: type 2 diabetes\nSeen on 2024-03-02. Patient reports occasional dizziness."))))
                .andExpect(status().isCreated());
        JsonNode sum = call(t, "/api/v1/ai/medical-summary", Map.of("externalProcessingConsent", true));
        System.out.println("LIVE summary: status=" + sum.get("aiStatus") + " model=" + sum.get("languageModel"));
        System.out.println("  explanation=" + sum.get("aiExplanation"));
        System.out.println("  facts=" + sum.get("documentedFacts").size() + " missing=" + sum.get("missingInformation"));
        assertThat(sum.get("aiStatus").asText()).isIn("OK", "FACTS_ONLY");
        assertThat(sum.get("allergies").toString()).containsIgnoringCase("penicillin");

        // text document stays deterministic
        String res = mvc.perform(multipart("/api/v1/ai/document-extraction")
                .file(new MockMultipartFile("file", "r.txt", "text/plain",
                        "Medication: Metformin 500mg\nHemoglobin: 13.2 g/dL\n".getBytes(StandardCharsets.UTF_8)))
                .header("Authorization", "Bearer " + t)).andExpect(status().isOk()).andReturn().getResponse()
                .getContentAsString();
        assertThat(res).contains("Metformin");
    }
}

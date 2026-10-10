package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/** Provider switched on but no API key configured: the app must keep working on rules and say so. */
@SpringBootTest(properties = {"app.ai.provider=anthropic", "app.ai.api-key="})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AiWithoutKeyTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired LlmGateway gateway;

    String patient() throws Exception {
        String email = "nk" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Demo-Password-123", "fullName", "P"))))
                .andExpect(status().isCreated());
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Demo-Password-123"))))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    @Test
    void featuresDegradeToRulesWhenTheKeyIsMissing() throws Exception {
        assertThat(gateway.configured()).isFalse();
        String t = patient();
        String tri = mvc.perform(post("/api/v1/ai/triage").header("Authorization", "Bearer " + t)
                .contentType(MediaType.APPLICATION_JSON).content("{\"symptoms\":\"mild cough since yesterday\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        JsonNode r = json.readTree(tri);
        assertThat(r.get("aiStatus").asText()).isEqualTo("NOT_CONFIGURED");
        assertThat(r.get("languageModel").asBoolean()).isFalse();
        assertThat(r.get("urgency").asText()).isEqualTo("ROUTINE");

        String sum = mvc.perform(post("/api/v1/ai/medical-summary").header("Authorization", "Bearer " + t)
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertThat(json.readTree(sum).get("languageModel").asBoolean()).isFalse();

        byte[] png = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
        String ext = mvc.perform(multipart("/api/v1/ai/document-extraction")
                .file(new MockMultipartFile("file", "a.png", "image/png", png))
                .param("externalProcessingConsent", "true").header("Authorization", "Bearer " + t))
                .andExpect(status().isUnprocessableEntity()).andReturn().getResponse().getContentAsString();
        assertThat(json.readTree(ext).get("code").asText()).isEqualTo("OCR_NOT_CONFIGURED");
    }
}

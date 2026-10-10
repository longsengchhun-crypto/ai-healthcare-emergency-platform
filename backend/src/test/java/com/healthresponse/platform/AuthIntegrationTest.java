package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    private JsonNode call(String url, Object body, int expected) throws Exception {
        String res = mvc.perform(post(url).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return res.isBlank() ? null : json.readTree(res);
    }

    private String uniqueEmail() { return "p" + UUID.randomUUID().toString().substring(0, 8) + "@example.test"; }

    @Test
    void registerLoginAndMe() throws Exception {
        String email = uniqueEmail();
        call("/api/v1/auth/register", Map.of("email", email, "password", "CorrectHorse-99", "fullName", "Test Patient"), 201);
        JsonNode login = call("/api/v1/auth/login", Map.of("email", email, "password", "CorrectHorse-99"), 200);
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + login.get("accessToken").asText()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.roles[0]").value("PATIENT"));
    }

    @Test
    void invalidLoginUsesGenericMessage() throws Exception {
        String email = uniqueEmail();
        call("/api/v1/auth/register", Map.of("email", email, "password", "CorrectHorse-99", "fullName", "T"), 201);
        JsonNode wrong = call("/api/v1/auth/login", Map.of("email", email, "password", "wrong-password-1"), 401);
        JsonNode unknown = call("/api/v1/auth/login", Map.of("email", uniqueEmail(), "password", "wrong-password-1"), 401);
        assertThat(wrong.get("message").asText()).isEqualTo(unknown.get("message").asText());
    }

    @Test
    void protectedEndpointRequiresToken() throws Exception {
        mvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer not.a.token")).andExpect(status().isUnauthorized());
    }

    @Test
    void refreshRotatesAndReuseRevokesFamily() throws Exception {
        String email = uniqueEmail();
        JsonNode first = call("/api/v1/auth/register", Map.of("email", email, "password", "CorrectHorse-99", "fullName", "T"), 201);
        String r1 = first.get("refreshToken").asText();
        JsonNode second = call("/api/v1/auth/refresh", Map.of("refreshToken", r1), 200);
        String r2 = second.get("refreshToken").asText();
        assertThat(r2).isNotEqualTo(r1);
        call("/api/v1/auth/refresh", Map.of("refreshToken", r1), 401);   // reuse of rotated token
        call("/api/v1/auth/refresh", Map.of("refreshToken", r2), 401);   // family was revoked
    }

    @Test
    void duplicateRegistrationIsRejected() throws Exception {
        String email = uniqueEmail();
        call("/api/v1/auth/register", Map.of("email", email, "password", "CorrectHorse-99", "fullName", "T"), 201);
        call("/api/v1/auth/register", Map.of("email", email, "password", "CorrectHorse-99", "fullName", "T"), 409);
    }

    @Test
    void weakInputIsRejectedWith422() throws Exception {
        call("/api/v1/auth/register", Map.of("email", "not-an-email", "password", "short", "fullName", "T"), 422);
    }
}

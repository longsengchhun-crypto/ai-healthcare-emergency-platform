package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.ai.LlmClient.LlmException.Kind;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** The real AiService/controller/security stack with the language model replaced by {@link ScriptedLlm}. */
@SpringBootTest(properties = "app.ai.provider=anthropic")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(AiProviderIntegrationTest.Config.class)
class AiProviderIntegrationTest {
    static final String PW = "Demo-Password-123";

    @TestConfiguration
    static class Config {
        @Bean ScriptedLlm scriptedLlm() { return new ScriptedLlm(); }
    }

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired ScriptedLlm llm;
    @Autowired LlmGateway gateway;

    @BeforeEach
    void clean() {
        llm.reset();
        gateway.reset();
    }

    // ---------------------------------------------------------------- helpers
    String newPatient() throws Exception {
        String email = "ai" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW, "fullName", "Pat Example"))))
                .andExpect(status().isCreated());
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    JsonNode send(MockHttpServletRequestBuilder b, String token, Object body, int expected) throws Exception {
        b.header("Authorization", "Bearer " + token);
        if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        String res = mvc.perform(b).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return res.isBlank() ? null : json.readTree(res);
    }

    JsonNode triage(String token, String text, int expected) throws Exception {
        return send(post("/api/v1/ai/triage"), token, Map.of("symptoms", text), expected);
    }

    static String triageJson(String severity) {
        return """
                {"severity":"%s","summary":"Your description does not suggest an immediate threat.",
                 "reasons":["You said you do not have chest pain and describe a mild cough."],
                 "nextSteps":["Rest and drink fluids.","Book an appointment if it lasts more than a week."],
                 "warningSigns":["Trouble breathing","Chest pain"],
                 "uncertainty":"Cannot examine you or know your history.",
                 "followUpQuestions":["How long have you had the cough?"]}""".formatted(severity);
    }

    JsonNode extract(String token, String name, String type, byte[] bytes, boolean consent, int expected) throws Exception {
        var b = multipart("/api/v1/ai/document-extraction")
                .file(new MockMultipartFile("file", name, type, bytes))
                .header("Authorization", "Bearer " + token);
        if (consent) b.param("externalProcessingConsent", "true");
        String res = mvc.perform(b).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return json.readTree(res);
    }

    static byte[] pdf() { return "%PDF-1.4 fake scanned lab report".getBytes(StandardCharsets.ISO_8859_1); }

    static byte[] png() {
        return new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
    }

    // ---------------------------------------------------------------- triage
    @Test
    void emergencyRuleReturnsImmediatelyWithoutCallingTheModel() throws Exception {
        String t = newPatient();
        llm.answer(triageJson("ROUTINE")); // would downgrade if it were ever used
        JsonNode r = triage(t, "I have crushing chest pain and my left arm is numb", 200);
        assertThat(r.get("urgency").asText()).isEqualTo("EMERGENCY");
        assertThat(r.get("emergencyActionRecommended").asBoolean()).isTrue();
        assertThat(r.get("assessedBy").asText()).isEqualTo("RULES");
        assertThat(r.get("aiStatus").asText()).isEqualTo("SKIPPED_EMERGENCY");
        assertThat(llm.seen).isEmpty();
    }

    @Test
    void negationIsInterpretedAndModelResultIsUsedWhenNoRuleFires() throws Exception {
        String t = newPatient();
        llm.answer(triageJson("ROUTINE"));
        JsonNode r = triage(t, "I have no chest pain, just a mild cough since yesterday", 200);
        assertThat(r.get("urgency").asText()).isEqualTo("ROUTINE");
        assertThat(r.get("assessedBy").asText()).isEqualTo("RULES+AI");
        assertThat(r.get("languageModel").asBoolean()).isTrue();
        assertThat(r.get("provider").asText()).isEqualTo("anthropic");
        assertThat(r.get("reasons").size()).isGreaterThan(0);
        assertThat(r.get("nextSteps").size()).isGreaterThan(0);
        assertThat(r.get("warningSigns").toString()).contains("Chest pain");
        assertThat(r.get("uncertainty").asText()).isNotBlank();
        assertThat(r.get("guidance").asText()).contains("cannot rule out");
        assertThat(r.get("notice").asText()).containsIgnoringCase("not a diagnosis");
        assertThat(llm.seen).hasSize(1);
        // the denial was passed on to the model as context
        assertThat(llm.seen.get(0).userText()).contains("CHEST_PAIN");
    }

    @Test
    void modelCanRaiseButNeverLowerWhatTheRulesDecided() throws Exception {
        String t = newPatient();
        llm.answer(triageJson("ROUTINE")); // model tries to downgrade a rule-based URGENT
        JsonNode urgent = triage(t, "I have the worst headache of my life since this morning", 200);
        assertThat(urgent.get("urgency").asText()).isEqualTo("URGENT");

        llm.answer(triageJson("EMERGENCY")); // model raises a rule-based ROUTINE
        JsonNode raised = triage(t, "I feel very strange and cold and my vision is going dark", 200);
        assertThat(raised.get("urgency").asText()).isEqualTo("EMERGENCY");
        assertThat(raised.get("emergencyActionRecommended").asBoolean()).isTrue();
    }

    @Test
    void contradictoryOrReversedDenialsStillTriggerTheEmergencyRule() throws Exception {
        String t = newPatient();
        for (String s : new String[] {
                "no chest pain but I can't breathe",
                "I don't have chest pain anymore but it was crushing earlier",
                "not sure if it is chest pain or heartburn",
                "no relief of my chest pain after resting"}) {
            JsonNode r = triage(t, s, 200);
            assertThat(r.get("urgency").asText()).as(s).isEqualTo("EMERGENCY");
        }
        assertThat(llm.seen).isEmpty();
    }

    @Test
    void providerFailuresFallBackToRulesAndAreNeverPresentedAsAiResults() throws Exception {
        String t = newPatient();
        Map<Kind, String> expected = Map.of(
                Kind.UNAVAILABLE, "UNAVAILABLE", Kind.AUTH, "PROVIDER_ERROR", Kind.RATE_LIMITED, "RATE_LIMITED",
                Kind.TIMEOUT, "TIMEOUT", Kind.CIRCUIT_OPEN, "UNAVAILABLE");
        for (var e : expected.entrySet()) {
            llm.fail(e.getKey());
            JsonNode r = triage(t, "mild runny nose since yesterday", 200);
            assertThat(r.get("aiStatus").asText()).as(e.getKey().name()).isEqualTo(e.getValue());
            assertThat(r.get("assessedBy").asText()).isEqualTo("RULES");
            assertThat(r.get("languageModel").asBoolean()).isFalse();
            assertThat(r.get("provider").asText()).isEqualTo("deterministic-demo");
            assertThat(r.get("urgency").asText()).isEqualTo("ROUTINE");
            assertThat(r.get("guidance").asText()).contains("cannot rule out");
            gateway.reset();
        }
    }

    @Test
    void unsafeOrMalformedModelOutputIsRejectedNotRepaired() throws Exception {
        String t = newPatient();
        String[] bad = {
                "this is not json at all",
                triageJson("ROUTINE").replace("Rest and drink fluids.", "Take 500 mg of paracetamol every 4 hours."),
                triageJson("ROUTINE").replace("does not suggest an immediate threat", "means there is no need to see a doctor"),
                triageJson("ROUTINE").replace("does not suggest an immediate threat", "means you have pneumonia"),
                triageJson("MILD"),
                "{\"severity\":\"ROUTINE\"}"};
        for (String b : bad) {
            llm.answer(b);
            JsonNode r = triage(t, "mild runny nose since yesterday", 200);
            assertThat(r.get("aiStatus").asText()).as(b).isEqualTo("OUTPUT_REJECTED");
            assertThat(r.get("assessedBy").asText()).isEqualTo("RULES");
        }
    }

    @Test
    void identifiersAreRedactedBeforeTheTextLeavesTheApplication() throws Exception {
        String t = newPatient();
        llm.answer(triageJson("ROUTINE"));
        triage(t, "Name: Sok Dara. Email sok.dara@example.com phone +855 12 345 678, NID 1234567890. "
                + "mild cough since 2024-03-02", 200);
        String sent = llm.seen.get(0).userText();
        assertThat(sent).doesNotContain("sok.dara@example.com").doesNotContain("345 678")
                .doesNotContain("1234567890").doesNotContain("Sok Dara");
        assertThat(sent).contains("mild cough").contains("2024-03-02");
    }

    @Test
    void perUserAiRateLimitReturnsRulesInsteadOfCallingTheProviderAgain() throws Exception {
        String t = newPatient();
        llm.fallback = r -> triageJson("ROUTINE");
        for (int i = 0; i < 10; i++) triage(t, "mild runny nose since yesterday", 200);
        JsonNode r = triage(t, "mild runny nose since yesterday", 200);
        assertThat(r.get("aiStatus").asText()).isEqualTo("RATE_LIMITED");
        assertThat(llm.seen).hasSize(10);
    }

    // ---------------------------------------------------------------- summary
    @Test
    void summaryKeepsOnlyFactsWhoseQuoteIsInTheRecordAndSeparatesTheExplanation() throws Exception {
        String t = newPatient();
        send(post("/api/v1/medical-records"), t, Map.of("recordType", "HISTORY", "title", "Hx",
                "body", "Allergy: shellfish\nMedication: Metformin 500mg twice daily\nSeen on 2024-03-02\n"
                        + "Patient felt dizzy after meals."), 201);
        llm.answer("""
                {"facts":[
                  {"category":"ALLERGY","value":"shellfish","recordRef":"R1","quote":"Allergy: shellfish"},
                  {"category":"OTHER","value":"dizzy after meals","recordRef":"R1","quote":"Patient felt dizzy after meals."},
                  {"category":"MEDICATION","value":"Warfarin 5mg","recordRef":"R1","quote":"Medication: Warfarin 5mg"},
                  {"category":"CONDITION","value":"asthma","recordRef":"R9","quote":"asthma"}],
                 "overview":"Your record lists a shellfish allergy and metformin.",
                 "missingInformation":["No blood pressure readings are recorded."],
                 "questionsForClinician":["Is the dizziness related to my medicine?"]}""");
        JsonNode s = send(post("/api/v1/ai/medical-summary"), t, Map.of(), 200);
        assertThat(s.get("languageModel").asBoolean()).isTrue();
        assertThat(s.get("aiStatus").asText()).isEqualTo("OK");
        assertThat(s.get("aiExplanation").asText()).contains("shellfish");
        assertThat(s.get("medications").toString()).contains("Metformin").doesNotContain("Warfarin");
        assertThat(s.get("allergies").toString()).contains("shellfish");
        assertThat(s.get("missingInformation").toString()).contains("blood pressure").contains("discarded");
        boolean sawDizzy = false;
        for (JsonNode f : s.get("documentedFacts")) {
            assertThat(f.get("sourceRecordId").asText()).isNotBlank();
            assertThat(f.get("quote").asText()).isNotBlank();
            if (f.get("value").asText().equals("dizzy after meals")) {
                sawDizzy = true;
                assertThat(f.get("origin").asText()).isEqualTo("MODEL_QUOTE_VERIFIED");
            }
        }
        assertThat(sawDizzy).isTrue();
        assertThat(s.get("sources").size()).isEqualTo(1);
        // the prompt contained only this user's record text
        assertThat(llm.seen.get(0).userText()).contains("Metformin").doesNotContain("Pat Example");
    }

    @Test
    void summaryRejectsAnExplanationThatIntroducesNumbersNotInTheRecords() throws Exception {
        String t = newPatient();
        send(post("/api/v1/medical-records"), t, Map.of("recordType", "HISTORY", "title", "Hx",
                "body", "Allergy: shellfish"), 201);
        llm.answer("""
                {"facts":[{"category":"ALLERGY","value":"shellfish","recordRef":"R1","quote":"Allergy: shellfish"}],
                 "overview":"You have a shellfish allergy and your last HbA1c was 9.4.",
                 "missingInformation":[],"questionsForClinician":[]}""");
        JsonNode s = send(post("/api/v1/ai/medical-summary"), t, Map.of(), 200);
        assertThat(s.get("aiStatus").asText()).isEqualTo("FACTS_ONLY");
        assertThat(s.path("aiExplanation").isMissingNode() || s.path("aiExplanation").isNull()).isTrue();
        assertThat(s.get("allergies").toString()).contains("shellfish");
    }

    @Test
    void summaryFallsBackToVerbatimExtractionWhenTheProviderFails() throws Exception {
        String t = newPatient();
        send(post("/api/v1/medical-records"), t, Map.of("recordType", "HISTORY", "title", "Hx",
                "body", "Allergy: shellfish\nMedication: Metformin 500mg"), 201);
        llm.fail(Kind.UNAVAILABLE);
        JsonNode s = send(post("/api/v1/ai/medical-summary"), t, Map.of(), 200);
        assertThat(s.get("aiStatus").asText()).isEqualTo("UNAVAILABLE");
        assertThat(s.get("languageModel").asBoolean()).isFalse();
        assertThat(s.get("allergies").toString()).contains("shellfish");
        assertThat(s.path("aiExplanation").isMissingNode() || s.path("aiExplanation").isNull()).isTrue();
        assertThat(s.get("notice").asText()).contains("not a language model");
    }

    @Test
    void summaryWithNoRecordsNeverCallsTheModel() throws Exception {
        String t = newPatient();
        JsonNode s = send(post("/api/v1/ai/medical-summary"), t, Map.of(), 200);
        assertThat(s.get("summary").asText()).contains("No medical records");
        assertThat(llm.seen).isEmpty();
    }

    @Test
    void anotherPatientsRecordsAreNeverAccessibleOrSent() throws Exception {
        String alice = newPatient();
        String bob = newPatient();
        send(post("/api/v1/medical-records"), alice, Map.of("recordType", "HISTORY", "title", "Alice secret",
                "body", "Diagnosis: very private condition"), 201);
        JsonNode bobSummary = send(post("/api/v1/ai/medical-summary"), bob, Map.of(), 200);
        assertThat(bobSummary.toString()).doesNotContain("private condition");
        assertThat(llm.seen).isEmpty();
        mvc.perform(post("/api/v1/ai/triage").contentType(MediaType.APPLICATION_JSON)
                .content("{\"symptoms\":\"mild cough since yesterday\"}")).andExpect(status().isUnauthorized());
    }

    // ---------------------------------------------------------------- document extraction
    @Test
    void pdfIsReadByTheModelAndEveryFieldIsFlaggedUnverified() throws Exception {
        String t = newPatient();
        llm.answer("""
                {"documentType":"TEST_REPORT","legible":true,
                 "fields":[
                  {"category":"TEST_VALUE","label":"Hemoglobin","value":"13.2 g/dL","evidence":"Hemoglobin 13.2 g/dL","confidence":"HIGH"},
                  {"category":"DATE","value":"31/02/2024","evidence":"Date: 31/02/2024","confidence":"HIGH"},
                  {"category":"MEDICATION","value":"Amoxicillin","evidence":"Amoxcillin 5OO","confidence":"LOW"},
                  {"category":"SECRET","value":"x","evidence":"x","confidence":"HIGH"}],
                 "warnings":["Bottom of the page is cut off."]}""");
        JsonNode r = extract(t, "lab.pdf", "application/pdf", pdf(), true, 200);
        assertThat(r.get("languageModel").asBoolean()).isTrue();
        assertThat(r.get("documentType").asText()).isEqualTo("TEST_REPORT");
        assertThat(r.get("fields").size()).isEqualTo(3); // SECRET category discarded
        for (JsonNode f : r.get("fields")) {
            assertThat(f.get("verification").asText()).isEqualTo("UNVERIFIED_MODEL_READ");
        }
        JsonNode hb = r.get("fields").get(0);
        assertThat(hb.get("name").asText()).isEqualTo("reportedValue:Hemoglobin");
        assertThat(hb.get("needsReview").asBoolean()).isFalse();
        JsonNode badDate = r.get("fields").get(1);
        assertThat(badDate.get("needsReview").asBoolean()).isTrue();
        assertThat(badDate.get("validationNotes").toString()).contains("valid calendar date");
        JsonNode med = r.get("fields").get(2);
        assertThat(med.get("needsReview").asBoolean()).isTrue();
        assertThat(med.get("validationNotes").toString()).contains("does not match");
        assertThat(r.get("needsReviewCount").asInt()).isEqualTo(2);
        assertThat(r.get("warnings").toString()).contains("cut off").contains("UNVERIFIED").contains("discarded");
        LlmClient.Attachment a = llm.seen.get(0).attachment();
        assertThat(a.mediaType()).isEqualTo("application/pdf");
    }

    @Test
    void imageWithoutExplicitConsentIsRejectedBeforeAnythingIsSent() throws Exception {
        String t = newPatient();
        JsonNode r = extract(t, "scan.png", "image/png", png(), false, 400);
        assertThat(r.get("code").asText()).isEqualTo("CONSENT_REQUIRED");
        assertThat(llm.seen).isEmpty();
    }

    @Test
    void fileTypeSizeAndContentAreValidatedBeforeProcessing() throws Exception {
        String t = newPatient();
        // declared PDF but really an executable
        assertThat(extract(t, "x.pdf", "application/pdf", "MZ\u0090\u0000fake exe".getBytes(StandardCharsets.ISO_8859_1),
                true, 400).get("code").asText()).isEqualTo("UNSUPPORTED_FILE");
        // declared as jpeg but PNG content
        assertThat(extract(t, "x.jpg", "image/jpeg", png(), true, 400).get("code").asText()).isEqualTo("UNSUPPORTED_FILE");
        // over 5 MB
        byte[] big = new byte[5 * 1024 * 1024 + 1];
        System.arraycopy(pdf(), 0, big, 0, pdf().length);
        assertThat(extract(t, "big.pdf", "application/pdf", big, true, 400).get("code").asText()).isEqualTo("FILE_TOO_LARGE");
        assertThat(llm.seen).isEmpty();
    }

    @Test
    void providerFailureOnAnImageReturnsAnErrorNotAFabricatedExtraction() throws Exception {
        String t = newPatient();
        llm.fail(Kind.UNAVAILABLE);
        JsonNode r = extract(t, "scan.png", "image/png", png(), true, 503);
        assertThat(r.get("code").asText()).isEqualTo("AI_UNAVAILABLE");
        assertThat(r.has("fields")).isFalse();
        llm.fail(Kind.RATE_LIMITED);
        assertThat(extract(t, "scan.png", "image/png", png(), true, 429).get("code").asText()).isEqualTo("AI_RATE_LIMITED");
        llm.answer("not json");
        assertThat(extract(t, "scan.png", "image/png", png(), true, 503).get("code").asText()).isEqualTo("AI_UNAVAILABLE");
    }

    @Test
    void plainTextExtractionStaysDeterministicAndNeverUsesTheProvider() throws Exception {
        String t = newPatient();
        JsonNode r = extract(t, "r.txt", "text/plain",
                "Medication: Metformin 500mg\nAllergy: shellfish\nHemoglobin: 13.2 g/dL\n".getBytes(StandardCharsets.UTF_8),
                false, 200);
        assertThat(r.get("languageModel").asBoolean()).isFalse();
        assertThat(r.get("fields").toString()).contains("Metformin").contains("shellfish").contains("13.2");
        assertThat(llm.seen).isEmpty();
    }
}

package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.admin.DemoDataSeeder;
import com.healthresponse.platform.ai.TriageEngine;
import java.time.LocalDate;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityAndRecordsIntegrationTest {
    static final String PW = "Demo-Password-123";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired TriageEngine triage;

    String login(String email) throws Exception {
        String res = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(res).get("accessToken").asText();
    }

    String newPatient() throws Exception {
        String email = "r" + UUID.randomUUID().toString().substring(0, 8) + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", PW, "fullName", "P"))))
                .andExpect(status().isCreated());
        return login(email);
    }

    JsonNode call(MockHttpServletRequestBuilder b, String token, Object body, int expected) throws Exception {
        b.header("Authorization", "Bearer " + token);
        if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        String res = mvc.perform(b).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return res.isBlank() ? null : json.readTree(res);
    }

    @Test
    void hospitalStaffCannotReadMedicalRecordsOrUseAdminEndpoints() throws Exception {
        String staff = login(DemoDataSeeder.STAFF);
        call(get("/api/v1/medical-records"), staff, null, 403);
        call(get("/api/v1/admin/users"), staff, null, 403);
        call(get("/api/v1/admin/audit-logs"), staff, null, 200); // staff has AUDIT_VIEW, not USER_ADMIN
    }

    @Test
    void patientCannotReachAdminOrClinicalEndpoints() throws Exception {
        String patient = newPatient();
        call(get("/api/v1/admin/users"), patient, null, 403);
        call(get("/api/v1/admin/audit-logs"), patient, null, 403);
        call(get("/api/v1/emergencies/responders"), patient, null, 403);
        call(post("/api/v1/medical-records"), patient,
                Map.of("recordType", "CLINICAL_NOTE", "title", "forged"), 400);
    }

    @Test
    void recordIsolationBetweenPatientsAndDoctorAccessRules() throws Exception {
        String alice = newPatient();
        String bob = newPatient();
        String doctor = login(DemoDataSeeder.DOCTOR);

        JsonNode rec = call(post("/api/v1/medical-records"), alice, Map.of("recordType", "HISTORY",
                "title", "My history", "body", "Allergy: pollen\nMedication: Vitamin D 2023-05-01"), 201);
        String id = rec.get("id").asText();
        assertThat(rec.get("authorKind").asText()).isEqualTo("PATIENT");

        call(get("/api/v1/medical-records/" + id), bob, null, 404);                  // other patient: IDOR blocked
        JsonNode bobList = call(get("/api/v1/medical-records"), bob, null, 200);
        assertThat(bobList.toString()).doesNotContain(id);

        // doctor without relationship/grant cannot read
        String alicePatientId = rec.get("patientId").asText();
        call(get("/api/v1/medical-records?patientId=" + alicePatientId), doctor, null, 404);

        // patient grants access -> doctor can read, then revoke -> blocked again
        String doctorId = call(get("/api/v1/doctors?q=Cardiology"), alice, null, 200).get("items").get(0).get("id").asText();
        String grantId = call(post("/api/v1/patients/me/access-grants"), alice, Map.of("doctorId", doctorId), 201)
                .get("id").asText();
        assertThat(call(get("/api/v1/medical-records?patientId=" + alicePatientId), doctor, null, 200).size()).isEqualTo(1);
        call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete(
                "/api/v1/patients/me/access-grants/" + grantId), alice, null, 204);
        call(get("/api/v1/medical-records?patientId=" + alicePatientId), doctor, null, 404);

        // access attempts were audited
        JsonNode audit = call(get("/api/v1/admin/audit-logs?action=RECORD_ACCESS&outcome=DENIED"),
                login(DemoDataSeeder.ADMIN), null, 200);
        assertThat(audit.get("total").asLong()).isGreaterThan(0);
    }

    @Test
    void clinicianAuthoredRecordsCannotBeAlteredByPatientsOnlyAmendedByAuthor() throws Exception {
        String patient = login(DemoDataSeeder.PATIENT);
        String doctor = login(DemoDataSeeder.DOCTOR);
        // doctor needs a relationship: patient grants access
        String patientProfile = call(get("/api/v1/patients/me"), patient, null, 200).get("id").asText();
        String doctorId = call(get("/api/v1/doctors?q=Cardiology"), patient, null, 200).get("items").get(0).get("id").asText();
        call(post("/api/v1/patients/me/access-grants"), patient, Map.of("doctorId", doctorId), 201);

        JsonNode note = call(post("/api/v1/medical-records"), doctor, Map.of("patientId", patientProfile,
                "recordType", "CLINICAL_NOTE", "title", "Follow-up", "body", "Diagnosis: demo hypertension"), 201);
        assertThat(note.get("authorKind").asText()).isEqualTo("CLINICIAN");
        String noteId = note.get("id").asText();

        // patient attempting to amend a clinician record is refused
        call(post("/api/v1/medical-records"), patient, Map.of("recordType", "HISTORY", "title", "x", "amendsId", noteId), 403);
        // author may amend (creates new record, original kept)
        JsonNode amended = call(post("/api/v1/medical-records"), doctor, Map.of("patientId", patientProfile,
                "recordType", "CLINICAL_NOTE", "title", "Follow-up (corrected)", "body", "Diagnosis: demo hypertension, stage 1",
                "amendsId", noteId), 201);
        assertThat(amended.get("amendsId").asText()).isEqualTo(noteId);
        assertThat(call(get("/api/v1/medical-records/" + noteId), patient, null, 200).get("title").asText()).isEqualTo("Follow-up");
    }

    @Test
    void uploadRejectsDisguisedFilesAndAcceptsRealPdf() throws Exception {
        String patient = newPatient();
        String recId = call(post("/api/v1/medical-records"), patient,
                Map.of("recordType", "DOCUMENT", "title", "Scan"), 201).get("id").asText();
        String url = "/api/v1/medical-records/" + recId + "/documents";

        MockMultipartFile fakePdf = new MockMultipartFile("file", "report.pdf", "application/pdf", "<script>alert(1)</script>".getBytes());
        mvc.perform(multipart(url).file(fakePdf).header("Authorization", "Bearer " + patient)).andExpect(status().isBadRequest());

        MockMultipartFile exe = new MockMultipartFile("file", "../../evil.exe", "application/octet-stream", new byte[]{'M', 'Z', 1, 2});
        mvc.perform(multipart(url).file(exe).header("Authorization", "Bearer " + patient)).andExpect(status().isBadRequest());

        MockMultipartFile pdf = new MockMultipartFile("file", "../lab report.pdf", "text/html",
                "%PDF-1.4\n%demo\n".getBytes());
        String res = mvc.perform(multipart(url).file(pdf).header("Authorization", "Bearer " + patient))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        JsonNode doc = json.readTree(res);
        assertThat(doc.get("contentType").asText()).isEqualTo("application/pdf");   // sniffed, not client-supplied
        assertThat(doc.get("fileName").asText()).doesNotContain("..").doesNotContain("/");

        // other patient cannot download
        String other = newPatient();
        mvc.perform(get(url + "/" + doc.get("id").asText()).header("Authorization", "Bearer " + other))
                .andExpect(status().isNotFound());
        mvc.perform(get(url + "/" + doc.get("id").asText()).header("Authorization", "Bearer " + patient))
                .andExpect(status().isOk());
    }

    @Test
    void triageEscalatesRedFlagsAndNeverReassures() {
        assertThat(triage.assess("I have crushing chest pain and my left arm is numb").urgency())
                .isEqualTo(TriageEngine.Urgency.EMERGENCY);
        assertThat(triage.assess("I can't breathe properly").urgency()).isEqualTo(TriageEngine.Urgency.EMERGENCY);
        assertThat(triage.assess("my father has slurred speech and face drooping").urgency())
                .isEqualTo(TriageEngine.Urgency.EMERGENCY);
        assertThat(triage.assess("I feel like I want to die").emergencyActionRecommended()).isTrue();
        assertThat(triage.assess("mild runny nose since yesterday").urgency()).isEqualTo(TriageEngine.Urgency.ROUTINE);
        assertThat(triage.assess("mild runny nose since yesterday").guidance()).contains("cannot rule out");
        assertThat(triage.assess("ok").urgency()).isEqualTo(TriageEngine.Urgency.UNCERTAIN);
    }

    @Test
    void aiSummaryUsesOnlyRecordedFactsAndIsLabelled() throws Exception {
        String patient = newPatient();
        call(post("/api/v1/medical-records"), patient, Map.of("recordType", "HISTORY", "title", "Hx",
                "body", "Allergy: shellfish\nMedication: Metformin 500mg\nDiagnosis: type 2 diabetes\nSeen on 2024-03-02"), 201);
        JsonNode s = call(post("/api/v1/ai/medical-summary"), patient, Map.of(), 200);
        assertThat(s.get("allergies").toString()).contains("shellfish");
        assertThat(s.get("medications").toString()).contains("Metformin");
        assertThat(s.get("languageModel").asBoolean()).isFalse();
        assertThat(s.get("notice").asText()).contains("not a language model");
        assertThat(s.get("sources").size()).isEqualTo(1);
    }

    @Test
    void medicationReminderLifecycleAndTimezoneValidation() throws Exception {
        String patient = newPatient();
        String medId = call(post("/api/v1/medications"), patient, Map.of("name", "Vitamin D", "dosage", "1000 IU"), 201)
                .get("id").asText();
        Map<String, Object> req = Map.of("medicationId", medId, "timeOfDay", "08:30:00", "timezone", "Asia/Phnom_Penh",
                "startDate", LocalDate.now().toString());
        JsonNode rem = call(post("/api/v1/medication-reminders"), patient, req, 201);
        assertThat(rem.get("active").asBoolean()).isTrue();
        assertThat(rem.get("nextOccurrence").asText()).isNotBlank();
        call(post("/api/v1/medication-reminders"), patient,
                Map.of("medicationId", medId, "timeOfDay", "08:30:00", "timezone", "Mars/Olympus", "startDate", LocalDate.now().toString()), 400);
        JsonNode off = call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch(
                "/api/v1/medication-reminders/" + rem.get("id").asText()), patient, Map.of("active", false), 200);
        assertThat(off.get("active").asBoolean()).isFalse();
        // another patient cannot touch it
        call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch(
                "/api/v1/medication-reminders/" + rem.get("id").asText()), newPatient(), Map.of("active", true), 404);
    }
}

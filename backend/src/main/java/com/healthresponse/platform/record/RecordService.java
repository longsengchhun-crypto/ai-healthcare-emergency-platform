package com.healthresponse.platform.record;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.common.AuditService;
import com.healthresponse.platform.common.Sql;
import com.healthresponse.platform.patient.PatientService;
import com.healthresponse.platform.security.AppProperties;
import com.healthresponse.platform.security.AuthPrincipal;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class RecordService {
    public record RecordView(UUID id, UUID patientId, String authorKind, String authorName, String recordType,
                             String title, String body, UUID amendsId, Instant createdAt, List<DocumentView> documents) {}
    public record DocumentView(UUID id, String fileName, String contentType, long sizeBytes, Instant createdAt) {}
    public record Download(Path path, String fileName, String contentType) {}

    static final Set<String> PATIENT_TYPES = Set.of("HISTORY", "DOCUMENT");
    static final Set<String> CLINICIAN_TYPES = Set.of("CLINICAL_NOTE", "PRESCRIPTION", "TEST_REPORT", "DISCHARGE_SUMMARY");
    static final long MAX_BYTES = 10L * 1024 * 1024;

    private final JdbcClient jdbc;
    private final PatientService patients;
    private final AuditService audit;
    private final Path root;

    public RecordService(JdbcClient jdbc, PatientService patients, AuditService audit, AppProperties props) throws IOException {
        this.jdbc = jdbc;
        this.patients = patients;
        this.audit = audit;
        this.root = Path.of(props.storage().root()).toAbsolutePath().normalize();
        Files.createDirectories(root);
    }

    // ------------------------------------------------------------ access control

    /** Resolves which patient profile the caller may read. Hospital staff/admins have no record access by design. */
    UUID authorizedPatientId(AuthPrincipal p, UUID requestedPatientId) {
        if (p.hasRole("PATIENT")) {
            UUID own = patients.patientIdFor(p.userId());
            if (requestedPatientId != null && !requestedPatientId.equals(own)) {
                audit.denied(p, "RECORD_ACCESS", "PATIENT", requestedPatientId);
                throw ApiException.notFound("Patient");
            }
            return own;
        }
        if (p.hasRole("DOCTOR") && requestedPatientId != null) {
            UUID doctorId = doctorIdFor(p.userId());
            int grants = jdbc.sql("""
                    SELECT COUNT(*) FROM record_access_grants g WHERE g.patient_id = :pt AND g.doctor_id = :d
                      AND g.revoked_at IS NULL AND (g.expires_at IS NULL OR g.expires_at > :now)""")
                    .param("pt", requestedPatientId).param("d", doctorId).param("now", Sql.ts(Instant.now()))
                    .query(Integer.class).single();
            int visits = jdbc.sql("""
                    SELECT COUNT(*) FROM appointments a WHERE a.patient_id = :pt AND a.doctor_id = :d
                      AND a.status IN ('CONFIRMED', 'COMPLETED')""")
                    .param("pt", requestedPatientId).param("d", doctorId).query(Integer.class).single();
            boolean related = grants + visits > 0;
            if (related) return requestedPatientId;
        }
        audit.denied(p, "RECORD_ACCESS", "PATIENT", requestedPatientId);
        throw ApiException.notFound("Patient");
    }

    private UUID doctorIdFor(UUID userId) {
        return jdbc.sql("SELECT id FROM doctor_profiles WHERE user_id = :u").param("u", userId).query(UUID.class).optional()
                .orElseThrow(() -> ApiException.forbidden("No doctor profile for this account"));
    }

    // ------------------------------------------------------------ reads

    public List<RecordView> list(AuthPrincipal p, UUID patientId) {
        UUID target = authorizedPatientId(p, patientId);
        List<RecordView> out = jdbc.sql(BASE + " WHERE r.patient_id = :p AND r.archived_at IS NULL ORDER BY r.created_at DESC")
                .param("p", target).query((rs, n) -> map(rs)).list();
        audit.ok(p, "RECORD_LIST", "PATIENT", target);
        return out.stream().map(r -> withDocs(r)).toList();
    }

    public RecordView get(AuthPrincipal p, UUID id) {
        RecordView r = jdbc.sql(BASE + " WHERE r.id = :id").param("id", id).query((rs, n) -> map(rs)).optional()
                .orElseThrow(() -> ApiException.notFound("Medical record"));
        authorizedPatientId(p, r.patientId());
        audit.ok(p, "RECORD_VIEW", "MEDICAL_RECORD", id);
        return withDocs(r);
    }

    private static final String BASE = """
            SELECT r.id, r.patient_id, r.author_kind, u.full_name AS author_name, r.record_type, r.title, r.body,
                   r.amends_id, r.created_at
            FROM medical_records r JOIN users u ON u.id = r.author_user_id""";

    private RecordView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new RecordView(rs.getObject("id", UUID.class), rs.getObject("patient_id", UUID.class),
                rs.getString("author_kind"), rs.getString("author_name"), rs.getString("record_type"),
                rs.getString("title"), rs.getString("body"), rs.getObject("amends_id", UUID.class),
                Sql.instant(rs, "created_at"), List.of());
    }

    private RecordView withDocs(RecordView r) {
        List<DocumentView> docs = jdbc.sql("""
                SELECT id, file_name, content_type, size_bytes, created_at FROM medical_record_documents
                WHERE record_id = :r ORDER BY created_at""").param("r", r.id())
                .query((rs, n) -> new DocumentView(rs.getObject("id", UUID.class), rs.getString("file_name"),
                        rs.getString("content_type"), rs.getLong("size_bytes"), Sql.instant(rs, "created_at"))).list();
        return new RecordView(r.id(), r.patientId(), r.authorKind(), r.authorName(), r.recordType(), r.title(),
                r.body(), r.amendsId(), r.createdAt(), docs);
    }

    // ------------------------------------------------------------ writes

    @Transactional
    public RecordView create(AuthPrincipal p, UUID patientId, String type, String title, String body, UUID amendsId) {
        boolean clinician = p.has("RECORD_WRITE_CLINICAL");
        UUID target;
        if (clinician) {
            if (patientId == null) throw ApiException.badRequest("PATIENT_REQUIRED", "patientId is required");
            target = authorizedPatientId(p, patientId);
            if (!CLINICIAN_TYPES.contains(type)) {
                throw ApiException.badRequest("INVALID_TYPE", "Clinicians may create: " + CLINICIAN_TYPES);
            }
        } else {
            target = patients.patientIdFor(p.userId());
            if (!PATIENT_TYPES.contains(type)) {
                throw ApiException.badRequest("INVALID_TYPE", "Patients may create: " + PATIENT_TYPES);
            }
        }
        if (amendsId != null) {
            // Amendments create a NEW record that references the original; originals are never edited.
            var orig = jdbc.sql("SELECT author_user_id, patient_id FROM medical_records WHERE id = :id").param("id", amendsId)
                    .query((rs, n) -> new Object[]{rs.getObject("author_user_id", UUID.class), rs.getObject("patient_id", UUID.class)})
                    .optional().orElseThrow(() -> ApiException.notFound("Medical record"));
            if (!p.userId().equals(orig[0]) || !target.equals(orig[1])) {
                audit.denied(p, "RECORD_AMEND", "MEDICAL_RECORD", amendsId);
                throw ApiException.forbidden("Only the original author can amend a record");
            }
        }
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO medical_records (id, patient_id, author_user_id, author_kind, record_type, title, body, amends_id, created_at)
                VALUES (:id, :p, :a, :k, :t, :ti, :b, :am, :now)""")
                .param("id", id).param("p", target).param("a", p.userId()).param("k", clinician ? "CLINICIAN" : "PATIENT")
                .param("t", type).param("ti", title).param("b", body).param("am", amendsId)
                .param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, amendsId == null ? "RECORD_CREATE" : "RECORD_AMEND", "MEDICAL_RECORD", id);
        return get(p, id);
    }

    @Transactional
    public DocumentView upload(AuthPrincipal p, UUID recordId, MultipartFile file) {
        RecordView rec = get(p, recordId);
        boolean ownerPatient = p.hasRole("PATIENT");
        if (ownerPatient && !"PATIENT".equals(rec.authorKind())) {
            throw ApiException.forbidden("Patients cannot attach files to clinician-authored records");
        }
        if (file.isEmpty()) throw ApiException.badRequest("EMPTY_FILE", "The uploaded file is empty");
        if (file.getSize() > MAX_BYTES) throw new ApiException(org.springframework.http.HttpStatus.PAYLOAD_TOO_LARGE,
                "FILE_TOO_LARGE", "File exceeds the 10 MB limit");
        UUID docId = UUID.randomUUID();
        Path target = root.resolve(docId.toString());
        String detected;
        String sha;
        try (InputStream in = file.getInputStream()) {
            byte[] head = in.readNBytes(8);
            detected = sniff(head);
            if (detected == null) {
                throw ApiException.badRequest("UNSUPPORTED_FILE", "Only PDF, PNG and JPEG files are accepted");
            }
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(head);
            try (DigestInputStream dis = new DigestInputStream(in, md)) {
                // write head + remainder to a private, non-public path named by an unguessable id
                Path tmp = Files.createTempFile(root, "upload-", ".part");
                try (var out = Files.newOutputStream(tmp)) {
                    out.write(head);
                    dis.transferTo(out);
                }
                Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
            }
            sha = HexFormat.of().formatHex(md.digest());
        } catch (IOException | java.security.NoSuchAlgorithmException e) {
            throw new ApiException(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR, "UPLOAD_FAILED", "File upload failed");
        }
        String safeName = sanitizeFileName(file.getOriginalFilename());
        jdbc.sql("""
                INSERT INTO medical_record_documents (id, record_id, file_name, content_type, size_bytes, storage_key, sha256, uploaded_by, created_at)
                VALUES (:id, :r, :n, :ct, :sz, :key, :sha, :u, :now)""")
                .param("id", docId).param("r", recordId).param("n", safeName).param("ct", detected)
                .param("sz", file.getSize()).param("key", docId.toString()).param("sha", sha).param("u", p.userId())
                .param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, "DOCUMENT_UPLOAD", "MEDICAL_RECORD", recordId);
        return new DocumentView(docId, safeName, detected, file.getSize(), Instant.now());
    }

    public Download download(AuthPrincipal p, UUID recordId, UUID docId) {
        RecordView rec = get(p, recordId);
        Optional<Object[]> doc = jdbc.sql("""
                SELECT file_name, content_type, storage_key FROM medical_record_documents WHERE id = :d AND record_id = :r""")
                .param("d", docId).param("r", rec.id())
                .query((rs, n) -> new Object[]{rs.getString(1), rs.getString(2), rs.getString(3)}).optional();
        if (doc.isEmpty()) throw ApiException.notFound("Document");
        Path file = root.resolve((String) doc.get()[2]).normalize();
        if (!file.startsWith(root) || !Files.exists(file)) throw ApiException.notFound("Document");
        audit.ok(p, "DOCUMENT_DOWNLOAD", "MEDICAL_RECORD", recordId);
        return new Download(file, (String) doc.get()[0], (String) doc.get()[1]);
    }

    // ------------------------------------------------------------ access grants

    @Transactional
    public UUID grantAccess(AuthPrincipal p, UUID doctorId) {
        UUID patientId = patients.patientIdFor(p.userId());
        boolean exists = jdbc.sql("SELECT COUNT(*) FROM doctor_profiles WHERE id = :d").param("d", doctorId)
                .query(Integer.class).single() > 0;
        if (!exists) throw ApiException.notFound("Doctor");
        UUID id = UUID.randomUUID();
        jdbc.sql("INSERT INTO record_access_grants (id, patient_id, doctor_id, created_at) VALUES (:id, :p, :d, :now)")
                .param("id", id).param("p", patientId).param("d", doctorId).param("now", Sql.ts(Instant.now())).update();
        audit.ok(p, "ACCESS_GRANT", "DOCTOR", doctorId);
        return id;
    }

    @Transactional
    public void revokeAccess(AuthPrincipal p, UUID grantId) {
        int n = jdbc.sql("""
                UPDATE record_access_grants SET revoked_at = :now WHERE id = :id AND patient_id = :p AND revoked_at IS NULL""")
                .param("now", Sql.ts(Instant.now())).param("id", grantId).param("p", patients.patientIdFor(p.userId())).update();
        if (n == 0) throw ApiException.notFound("Access grant");
        audit.ok(p, "ACCESS_REVOKE", "ACCESS_GRANT", grantId);
    }

    // ------------------------------------------------------------ helpers

    /** Content sniffing on magic bytes; the client-supplied Content-Type is never trusted. */
    static String sniff(byte[] h) {
        if (h.length >= 5 && h[0] == '%' && h[1] == 'P' && h[2] == 'D' && h[3] == 'F' && h[4] == '-') return "application/pdf";
        if (h.length >= 8 && (h[0] & 0xFF) == 0x89 && h[1] == 'P' && h[2] == 'N' && h[3] == 'G') return "image/png";
        if (h.length >= 3 && (h[0] & 0xFF) == 0xFF && (h[1] & 0xFF) == 0xD8 && (h[2] & 0xFF) == 0xFF) return "image/jpeg";
        return null;
    }

    static String sanitizeFileName(String name) {
        String base = name == null ? "document" : name.replace('\\', '/');
        base = base.substring(base.lastIndexOf('/') + 1).replaceAll("[^A-Za-z0-9._ -]", "_");
        if (base.isBlank()) base = "document";
        return base.length() > 120 ? base.substring(base.length() - 120) : base;
    }
}

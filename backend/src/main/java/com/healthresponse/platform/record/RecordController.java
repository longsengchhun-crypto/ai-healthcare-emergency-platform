package com.healthresponse.platform.record;

import com.healthresponse.platform.record.RecordService.Download;
import com.healthresponse.platform.record.RecordService.DocumentView;
import com.healthresponse.platform.record.RecordService.RecordView;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class RecordController {
    public record CreateRequest(UUID patientId, @NotBlank String recordType, @NotBlank @Size(max = 200) String title,
                                @Size(max = 20000) String body, UUID amendsId) {}
    public record GrantRequest(@NotNull UUID doctorId) {}

    private final RecordService service;

    public RecordController(RecordService service) { this.service = service; }

    @GetMapping("/medical-records")
    @PreAuthorize("hasAnyAuthority('RECORD_VIEW_OWN', 'RECORD_WRITE_CLINICAL')")
    public List<RecordView> list(@AuthenticationPrincipal AuthPrincipal p, @RequestParam(required = false) UUID patientId) {
        return service.list(p, patientId);
    }

    @GetMapping("/medical-records/{id}")
    @PreAuthorize("hasAnyAuthority('RECORD_VIEW_OWN', 'RECORD_WRITE_CLINICAL')")
    public RecordView get(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.get(p, id);
    }

    @PostMapping("/medical-records")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('RECORD_VIEW_OWN', 'RECORD_WRITE_CLINICAL')")
    public RecordView create(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody CreateRequest r) {
        return service.create(p, r.patientId(), r.recordType(), r.title(), r.body(), r.amendsId());
    }

    @PostMapping(value = "/medical-records/{id}/documents", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('RECORD_VIEW_OWN', 'RECORD_WRITE_CLINICAL')")
    public DocumentView upload(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                               @RequestParam("file") MultipartFile file) {
        return service.upload(p, id, file);
    }

    @GetMapping("/medical-records/{id}/documents/{docId}")
    @PreAuthorize("hasAnyAuthority('RECORD_VIEW_OWN', 'RECORD_WRITE_CLINICAL')")
    public ResponseEntity<Resource> download(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                             @PathVariable UUID docId) {
        Download d = service.download(p, id, docId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(d.contentType()))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(d.fileName()).build().toString())
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(new FileSystemResource(d.path()));
    }

    @PostMapping("/patients/me/access-grants")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('PROFILE_OWN')")
    public Map<String, UUID> grant(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody GrantRequest r) {
        return Map.of("id", service.grantAccess(p, r.doctorId()));
    }

    @DeleteMapping("/patients/me/access-grants/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('PROFILE_OWN')")
    public void revoke(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        service.revokeAccess(p, id);
    }
}

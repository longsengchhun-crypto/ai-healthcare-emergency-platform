package com.healthresponse.platform.ai;

import com.healthresponse.platform.ai.AiService.ExtractionResult;
import com.healthresponse.platform.ai.AiService.SummaryResult;
import com.healthresponse.platform.ai.TriageEngine.Result;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/ai")
@PreAuthorize("hasAuthority('AI_USE')")
public class AiController {
    public record SummaryRequest(UUID patientId) {}
    public record TriageRequest(@NotBlank @Size(max = 2000) String symptoms) {}

    private final AiService service;

    public AiController(AiService service) { this.service = service; }

    @PostMapping("/medical-summary")
    public SummaryResult summary(@AuthenticationPrincipal AuthPrincipal p, @RequestBody(required = false) SummaryRequest r) {
        return service.summarize(p, r == null ? null : r.patientId());
    }

    @PostMapping(value = "/document-extraction", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ExtractionResult extract(@AuthenticationPrincipal AuthPrincipal p, @RequestParam("file") MultipartFile file) {
        return service.extract(p, file);
    }

    @PostMapping("/triage")
    public Result triage(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody TriageRequest r) {
        return service.triage(p, r.symptoms());
    }
}

package com.healthresponse.platform.ai;

import com.healthresponse.platform.ai.AiService.ExtractionResult;
import com.healthresponse.platform.ai.AiService.TriageOutcome;
import com.healthresponse.platform.ai.AiService.SummaryResult;
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
    public record SummaryRequest(UUID patientId, Boolean externalProcessingConsent) {}
    public record AiStatus(String provider, String displayName, boolean configured, boolean externalRequested,
                           boolean providerMayUseDataForTraining) {}
    public record TriageRequest(@NotBlank @Size(max = 2000) String symptoms) {}

    private final AiService service;
    private final LlmGateway gateway;

    public AiController(AiService service, LlmGateway gateway) {
        this.service = service;
        this.gateway = gateway;
    }

    /** What the app needs to show an honest consent text; never includes the key. */
    @GetMapping("/status")
    public AiStatus status() {
        return new AiStatus(gateway.providerName(), gateway.displayName(), gateway.configured(),
                gateway.externalRequested(), gateway.configured() && gateway.providerMayUseDataForTraining());
    }

    @PostMapping("/medical-summary")
    public SummaryResult summary(@AuthenticationPrincipal AuthPrincipal p, @RequestBody(required = false) SummaryRequest r) {
        return service.summarize(p, r == null ? null : r.patientId(),
                r != null && Boolean.TRUE.equals(r.externalProcessingConsent()));
    }

    @PostMapping(value = "/document-extraction", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ExtractionResult extract(@AuthenticationPrincipal AuthPrincipal p, @RequestParam("file") MultipartFile file,
                                    @RequestParam(value = "externalProcessingConsent", defaultValue = "false")
                                    boolean externalProcessingConsent) {
        return service.extract(p, file, externalProcessingConsent);
    }

    @PostMapping("/triage")
    public TriageOutcome triage(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody TriageRequest r) {
        return service.triage(p, r.symptoms());
    }
}

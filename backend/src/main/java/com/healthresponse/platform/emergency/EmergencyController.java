package com.healthresponse.platform.emergency;

import com.healthresponse.platform.common.ApiException;
import com.healthresponse.platform.emergency.EmergencyService.CreateCommand;
import com.healthresponse.platform.emergency.EmergencyService.EmergencyView;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/emergencies")
public class EmergencyController {
    public record CreateRequest(@Size(max = 500) String description,
                                @Pattern(regexp = "^(MANUAL|SENSOR_COUNTDOWN)$") String triggerSource,
                                boolean demo,
                                @DecimalMin("-90") @DecimalMax("90") Double latitude,
                                @DecimalMin("-180") @DecimalMax("180") Double longitude,
                                Double accuracyMeters) {}
    public record AssignRequest(@NotNull UUID responderId) {}
    public record StatusRequest(@NotBlank String status, @Size(max = 500) String note) {}
    public record CancelRequest(@Size(max = 500) String note) {}

    private final EmergencyService service;

    public EmergencyController(EmergencyService service) { this.service = service; }

    /** Idempotency-Key is mandatory so a network retry can never create a second event. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('EMERGENCY_CREATE')")
    public EmergencyView create(@AuthenticationPrincipal AuthPrincipal p,
                                @RequestHeader(value = "Idempotency-Key", required = false) String key,
                                @Valid @RequestBody CreateRequest r) {
        if (key == null || key.isBlank() || key.length() > 80) {
            throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "An Idempotency-Key header (max 80 chars) is required");
        }
        if ((r.latitude() == null) != (r.longitude() == null)) {
            throw ApiException.badRequest("INVALID_LOCATION", "Latitude and longitude must be provided together");
        }
        return service.create(p, new CreateCommand(key, r.description(),
                r.triggerSource() == null ? "MANUAL" : r.triggerSource(), r.demo(),
                r.latitude(), r.longitude(), r.accuracyMeters()));
    }

    @GetMapping
    public List<EmergencyView> list(@AuthenticationPrincipal AuthPrincipal p,
                                    @RequestParam(required = false) String status,
                                    @RequestParam(defaultValue = "50") int limit) {
        return service.list(p, status, limit);
    }

    @GetMapping("/{id}")
    public EmergencyView get(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.get(p, id);
    }

    @PostMapping("/{id}/acknowledge")
    @PreAuthorize("hasAuthority('EMERGENCY_MANAGE')")
    public EmergencyView acknowledge(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.acknowledge(p, id);
    }

    @PostMapping("/{id}/assign")
    @PreAuthorize("hasAuthority('EMERGENCY_MANAGE')")
    public EmergencyView assign(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                @Valid @RequestBody AssignRequest r) {
        return service.assign(p, id, r.responderId());
    }

    @PostMapping("/{id}/status")
    @PreAuthorize("hasAuthority('EMERGENCY_MANAGE')")
    public EmergencyView status(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                @Valid @RequestBody StatusRequest r) {
        return service.updateStatus(p, id, r.status(), r.note());
    }

    @PostMapping("/{id}/cancel")
    public EmergencyView cancel(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                @Valid @RequestBody(required = false) CancelRequest r) {
        return service.cancel(p, id, r == null ? null : r.note());
    }
}

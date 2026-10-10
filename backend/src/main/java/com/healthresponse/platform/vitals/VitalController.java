package com.healthresponse.platform.vitals;

import com.healthresponse.platform.security.AuthPrincipal;
import com.healthresponse.platform.vitals.VitalService.SummaryItem;
import com.healthresponse.platform.vitals.VitalService.VitalView;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/vitals")
@PreAuthorize("hasAuthority('PROFILE_OWN')")
public class VitalController {
    public record VitalRequest(@NotBlank @Size(max = 30) String type, @NotNull Double value1, Double value2,
                               @Size(max = 300) String note, Instant measuredAt) {}

    private final VitalService service;

    public VitalController(VitalService service) { this.service = service; }

    @GetMapping
    public List<VitalView> list(@AuthenticationPrincipal AuthPrincipal p,
                                @RequestParam(required = false) String type,
                                @RequestParam(defaultValue = "90") int days) {
        return service.list(p, type, days);
    }

    @GetMapping("/summary")
    public List<SummaryItem> summary(@AuthenticationPrincipal AuthPrincipal p) { return service.summary(p); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VitalView add(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody VitalRequest r) {
        return service.add(p, r.type(), r.value1(), r.value2(), r.note(), r.measuredAt());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        service.delete(p, id);
    }
}

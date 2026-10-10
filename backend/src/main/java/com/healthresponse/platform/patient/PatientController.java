package com.healthresponse.platform.patient;

import com.healthresponse.platform.patient.PatientService.Contact;
import com.healthresponse.platform.patient.PatientService.Profile;
import com.healthresponse.platform.patient.PatientService.ProfileUpdate;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/patients/me")
@PreAuthorize("hasAuthority('PROFILE_OWN')")
public class PatientController {
    public record UpdateRequest(@Size(min = 1, max = 150) String fullName,
                                @Pattern(regexp = "^\\+?[0-9 ()-]{6,32}$", message = "invalid phone number") String phone,
                                LocalDate dateOfBirth,
                                @Pattern(regexp = "^(MALE|FEMALE|OTHER|UNDISCLOSED)$") String gender,
                                @Pattern(regexp = "^(A|B|AB|O)[+-]$", message = "invalid blood group") String bloodGroup,
                                @Size(max = 1000) String allergies, @Size(max = 1000) String conditions,
                                @Size(max = 255) String address) {}
    public record ContactRequest(@NotBlank @Size(max = 150) String name, @Size(max = 60) String relationship,
                                 @NotBlank @Pattern(regexp = "^\\+?[0-9 ()-]{6,32}$") String phone,
                                 @Min(1) @Max(5) Integer priority) {}

    private final PatientService service;

    public PatientController(PatientService service) { this.service = service; }

    @GetMapping
    public Profile get(@AuthenticationPrincipal AuthPrincipal p) { return service.get(p); }

    @PatchMapping
    public Profile update(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody UpdateRequest r) {
        return service.update(p, new ProfileUpdate(r.fullName(), r.phone(), r.dateOfBirth(), r.gender(),
                r.bloodGroup(), r.allergies(), r.conditions(), r.address()));
    }

    @GetMapping("/emergency-contacts")
    public List<Contact> contacts(@AuthenticationPrincipal AuthPrincipal p) { return service.contacts(p); }

    @PostMapping("/emergency-contacts")
    @ResponseStatus(HttpStatus.CREATED)
    public Contact addContact(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody ContactRequest r) {
        return service.addContact(p, r.name(), r.relationship(), r.phone(), r.priority() == null ? 1 : r.priority());
    }

    @DeleteMapping("/emergency-contacts/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteContact(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        service.deleteContact(p, id);
    }

    @GetMapping("/privacy")
    public Map<String, Object> privacy(@AuthenticationPrincipal AuthPrincipal p) { return service.privacySummary(p); }
}

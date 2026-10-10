package com.healthresponse.platform.medication;

import com.healthresponse.platform.medication.MedicationService.MedicationView;
import com.healthresponse.platform.medication.MedicationService.ReminderView;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@PreAuthorize("hasAuthority('PROFILE_OWN')")
public class MedicationController {
    public record MedicationRequest(@NotBlank @Size(max = 150) String name, @Size(max = 100) String dosage,
                                    @Size(max = 500) String instructions) {}
    public record ReminderRequest(@NotNull UUID medicationId, @NotNull LocalTime timeOfDay,
                                  @NotBlank @Size(max = 60) String timezone, @NotNull LocalDate startDate, LocalDate endDate) {}
    public record ReminderPatch(Boolean active, LocalTime timeOfDay, LocalDate endDate) {}
    public record AdherenceRequest(@NotBlank @Pattern(regexp = "^(TAKEN|SKIPPED)$") String outcome) {}

    private final MedicationService service;

    public MedicationController(MedicationService service) { this.service = service; }

    @GetMapping("/medications")
    public List<MedicationView> medications(@AuthenticationPrincipal AuthPrincipal p) { return service.medications(p); }

    @PostMapping("/medications")
    @ResponseStatus(HttpStatus.CREATED)
    public MedicationView add(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody MedicationRequest r) {
        return service.addMedication(p, r.name(), r.dosage(), r.instructions());
    }

    @GetMapping("/medication-reminders")
    public List<ReminderView> reminders(@AuthenticationPrincipal AuthPrincipal p) { return service.reminders(p); }

    @PostMapping("/medication-reminders")
    @ResponseStatus(HttpStatus.CREATED)
    public ReminderView addReminder(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody ReminderRequest r) {
        return service.addReminder(p, r.medicationId(), r.timeOfDay(), r.timezone(), r.startDate(), r.endDate());
    }

    @PatchMapping("/medication-reminders/{id}")
    public ReminderView patch(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                              @Valid @RequestBody ReminderPatch r) {
        return service.updateReminder(p, id, r.active(), r.timeOfDay(), r.endDate());
    }

    @PostMapping("/medication-reminders/{id}/adherence")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void adherence(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                          @Valid @RequestBody AdherenceRequest r) {
        service.recordAdherence(p, id, r.outcome());
    }
}

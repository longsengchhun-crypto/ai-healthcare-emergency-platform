package com.healthresponse.platform.appointment;

import com.healthresponse.platform.appointment.AppointmentService.AppointmentView;
import com.healthresponse.platform.directory.DirectoryService.Page;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/appointments")
public class AppointmentController {
    public record BookRequest(@NotNull UUID doctorId, @NotNull Instant startsAt, @Size(max = 500) String reason) {}
    public record RescheduleRequest(@NotNull Instant startsAt) {}

    private final AppointmentService service;

    public AppointmentController(AppointmentService service) { this.service = service; }

    @GetMapping
    public Page<AppointmentView> list(@AuthenticationPrincipal AuthPrincipal p,
                                      @RequestParam(defaultValue = "0") int page,
                                      @RequestParam(defaultValue = "20") int size) {
        return service.list(p, page, size);
    }

    @GetMapping("/{id}")
    public AppointmentView get(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.get(p, id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('APPOINTMENT_BOOK')")
    public AppointmentView book(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody BookRequest r) {
        return service.book(p, r.doctorId(), r.startsAt(), r.reason());
    }

    /** Only the new time is accepted; status can never be supplied by the client. */
    @PatchMapping("/{id}")
    @PreAuthorize("hasAuthority('APPOINTMENT_BOOK')")
    public AppointmentView reschedule(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id,
                                      @Valid @RequestBody RescheduleRequest r) {
        return service.reschedule(p, id, r.startsAt());
    }

    @PostMapping("/{id}/confirm")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    public AppointmentView confirm(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.confirm(p, id);
    }

    @PostMapping("/{id}/reject")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    public AppointmentView reject(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.reject(p, id);
    }

    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAuthority('APPOINTMENT_DOCTOR')")
    public AppointmentView complete(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.complete(p, id);
    }

    @PostMapping("/{id}/cancel")
    public AppointmentView cancel(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        return service.cancel(p, id);
    }
}

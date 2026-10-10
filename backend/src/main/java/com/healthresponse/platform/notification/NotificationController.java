package com.healthresponse.platform.notification;

import com.healthresponse.platform.notification.NotificationService.NotificationView;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class NotificationController {
    public record DeviceRequest(@NotBlank @Size(max = 512) String token,
                                @NotBlank @Pattern(regexp = "^(ANDROID|IOS|WEB)$") String platform) {}

    private final NotificationService service;

    public NotificationController(NotificationService service) { this.service = service; }

    @GetMapping("/notifications")
    public Map<String, Object> list(@AuthenticationPrincipal AuthPrincipal p,
                                    @RequestParam(defaultValue = "50") int limit) {
        List<NotificationView> items = service.list(p.userId(), limit);
        return Map.of("items", items, "unread", service.unreadCount(p.userId()));
    }

    @PostMapping("/notifications/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void read(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        service.markRead(p.userId(), id);
    }

    @PostMapping("/devices/register")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, UUID> register(@AuthenticationPrincipal AuthPrincipal p, @Valid @RequestBody DeviceRequest r) {
        return Map.of("id", service.registerDevice(p.userId(), r.token(), r.platform()));
    }

    @DeleteMapping("/devices/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@AuthenticationPrincipal AuthPrincipal p, @PathVariable UUID id) {
        service.removeDevice(p.userId(), id);
    }
}

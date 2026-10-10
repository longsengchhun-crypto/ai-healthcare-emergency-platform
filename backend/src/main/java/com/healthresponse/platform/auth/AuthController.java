package com.healthresponse.platform.auth;

import com.healthresponse.platform.auth.AuthService.TokenPair;
import com.healthresponse.platform.security.AuthPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AuthController {
    public record RegisterRequest(@NotBlank @Email @Size(max = 255) String email,
                                  @NotBlank @Size(min = 10, max = 100, message = "must be 10-100 characters") String password,
                                  @NotBlank @Size(max = 150) String fullName,
                                  @Size(max = 32) String phone,
                                  @Size(max = 120) String deviceLabel) {}
    public record LoginRequest(@NotBlank @Email String email, @NotBlank String password, @Size(max = 120) String deviceLabel) {}
    public record RefreshRequest(@NotBlank String refreshToken) {}
    public record ResetRequest(@NotBlank @Email String email) {}
    public record ResetConfirmRequest(@NotBlank String token,
                                      @NotBlank @Size(min = 10, max = 100) String newPassword) {}

    private final AuthService auth;
    private final org.springframework.jdbc.core.simple.JdbcClient jdbc;

    public AuthController(AuthService auth, org.springframework.jdbc.core.simple.JdbcClient jdbc) {
        this.auth = auth;
        this.jdbc = jdbc;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenPair register(@Valid @RequestBody RegisterRequest r) {
        return auth.registerPatient(r.email(), r.password(), r.fullName(), r.phone(), r.deviceLabel());
    }

    @PostMapping("/auth/login")
    public TokenPair login(@Valid @RequestBody LoginRequest r) {
        return auth.login(r.email(), r.password(), r.deviceLabel());
    }

    @PostMapping("/auth/refresh")
    public TokenPair refresh(@Valid @RequestBody RefreshRequest r) {
        return auth.refresh(r.refreshToken());
    }

    @PostMapping("/auth/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest r) {
        auth.logout(r.refreshToken());
    }

    /** Always 202 regardless of whether the account exists, to prevent account enumeration. */
    @PostMapping("/auth/password-reset")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, String> requestReset(@Valid @RequestBody ResetRequest r) {
        auth.requestPasswordReset(r.email());
        return Map.of("message", "If an account exists for that address, reset instructions will be sent.");
    }

    @PostMapping("/auth/password-reset/confirm")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void confirmReset(@Valid @RequestBody ResetConfirmRequest r) {
        auth.confirmPasswordReset(r.token(), r.newPassword());
    }

    @GetMapping("/users/me")
    public Map<String, Object> me(@AuthenticationPrincipal AuthPrincipal p) {
        String name = jdbc.sql("SELECT full_name FROM users WHERE id = :id").param("id", p.userId())
                .query(String.class).optional().orElse("");
        return Map.of("id", p.userId(), "email", p.email(), "fullName", name,
                "roles", p.roles(), "permissions", p.permissions());
    }
}

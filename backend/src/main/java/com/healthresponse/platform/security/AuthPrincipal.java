package com.healthresponse.platform.security;

import java.util.Set;
import java.util.UUID;

/** Authenticated caller. Roles and permissions are loaded server-side from the database, never from the client. */
public record AuthPrincipal(UUID userId, String email, Set<String> roles, Set<String> permissions) {
    public boolean has(String permission) { return permissions.contains(permission); }
    public boolean hasRole(String role) { return roles.contains(role); }
    public String primaryRole() { return roles.stream().sorted().findFirst().orElse("NONE"); }
}

package com.healthresponse.platform.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

/** Issues and validates short-lived access tokens. The token carries only the user id; authorities come from the DB. */
@Service
public class JwtService {
    private final SecretKey key;
    private final int accessTtlMinutes;

    public JwtService(AppProperties props) {
        String secret = props.jwt().secret();
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("app.jwt.secret (JWT_SECRET) must be set to at least 32 bytes");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTtlMinutes = props.jwt().accessTtlMinutes();
    }

    public String issue(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder().subject(userId.toString()).issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(accessTtlMinutes * 60L))).signWith(key).compact();
    }

    public int accessTtlSeconds() { return accessTtlMinutes * 60; }

    /** Returns the user id, or null if the token is invalid or expired. */
    public UUID validate(String token) {
        try {
            Claims c = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            return UUID.fromString(c.getSubject());
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }
    }
}

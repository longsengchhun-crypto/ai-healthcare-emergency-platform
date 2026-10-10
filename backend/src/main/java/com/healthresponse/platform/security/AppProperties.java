package com.healthresponse.platform.security;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors, Storage storage, Seed seed, Ai ai, Fcm fcm, RateLimit rateLimit) {
    public record Jwt(String secret, int accessTtlMinutes, int refreshTtlDays) {}
    public record Cors(List<String> allowedOrigins) {}
    public record Storage(String root) {}
    public record Seed(boolean demoEnabled, String demoPassword) {}
    /** provider: deterministic-demo (rules only) | anthropic (Claude API; needs apiKey). Key comes from AI_API_KEY only. */
    public record Ai(String provider, String apiKey, String model, int timeoutSeconds, int maxRetries,
                     int rateLimitPerMinute, String baseUrl) {}
    public record Fcm(boolean enabled) {}
    public record RateLimit(int authPerMinute) {}
}

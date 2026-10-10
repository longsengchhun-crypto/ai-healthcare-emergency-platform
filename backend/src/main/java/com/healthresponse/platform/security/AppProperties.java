package com.healthresponse.platform.security;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors, Storage storage, Seed seed, Ai ai, Fcm fcm, RateLimit rateLimit) {
    public record Jwt(String secret, int accessTtlMinutes, int refreshTtlDays) {}
    public record Cors(List<String> allowedOrigins) {}
    public record Storage(String root) {}
    public record Seed(boolean demoEnabled, String demoPassword) {}
    public record Ai(String provider, String apiKey) {}
    public record Fcm(boolean enabled) {}
    public record RateLimit(int authPerMinute) {}
}

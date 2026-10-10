package com.healthresponse.platform.ai;

import com.healthresponse.platform.ai.LlmClient.LlmException;
import com.healthresponse.platform.ai.LlmClient.LlmException.Kind;
import com.healthresponse.platform.security.AppProperties;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Single door to the language model: availability check, per-user rate limit (cost/abuse control) and a small
 * circuit breaker so a failing provider cannot stack up 20-second timeouts. The credential is read only from the
 * backend environment (AI_API_KEY); it is never returned by any API.
 */
@Component
public class LlmGateway {
    public static final String PROVIDER_ANTHROPIC = "anthropic";
    private static final int BREAKER_THRESHOLD = 5;
    private static final long BREAKER_OPEN_MS = 60_000;

    private final LlmClient client;
    private final String providerName;
    private final int perMinute;
    private final Map<UUID, Deque<Long>> calls = new ConcurrentHashMap<>();
    private int consecutiveFailures;
    private long openUntil;

    public LlmGateway(AppProperties props, ObjectProvider<LlmClient> injected) {
        AppProperties.Ai ai = props.ai();
        this.providerName = ai.provider();
        this.perMinute = ai.rateLimitPerMinute() > 0 ? ai.rateLimitPerMinute() : 10;
        LlmClient c = null;
        if (PROVIDER_ANTHROPIC.equals(providerName)) {
            c = injected.getIfAvailable();
            if (c == null && ai.apiKey() != null && !ai.apiKey().isBlank()) {
                c = new AnthropicLlmClient(ai.apiKey().trim(),
                        ai.model() == null || ai.model().isBlank() ? "claude-opus-5-5" : ai.model().trim(),
                        Duration.ofSeconds(ai.timeoutSeconds() > 0 ? ai.timeoutSeconds() : 20),
                        Math.max(0, ai.maxRetries()), ai.baseUrl());
            }
        }
        this.client = c;
    }

    /** Test support: clears rate-limit windows and circuit-breaker state. */
    void reset() {
        calls.clear();
        synchronized (this) {
            consecutiveFailures = 0;
            openUntil = 0;
        }
    }

    /** True only when the provider is set to "anthropic" and a usable client exists. */
    public boolean configured() { return client != null; }

    /** True when an external provider was requested (even if its credential is missing). */
    public boolean externalRequested() { return PROVIDER_ANTHROPIC.equals(providerName); }

    public String providerName() { return configured() ? PROVIDER_ANTHROPIC : "deterministic-demo"; }

    public String complete(UUID userId, LlmClient.Request request) {
        if (client == null) throw new LlmException(Kind.NOT_CONFIGURED, "AI provider is not configured");
        long now = System.currentTimeMillis();
        synchronized (this) {
            if (now < openUntil) throw new LlmException(Kind.CIRCUIT_OPEN, "AI provider temporarily paused");
        }
        Deque<Long> q = calls.computeIfAbsent(userId, k -> new ArrayDeque<>());
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekFirst() > 60_000) q.pollFirst();
            if (q.size() >= perMinute) throw new LlmException(Kind.LOCAL_LIMIT, "Too many AI requests");
            q.addLast(now);
        }
        try {
            String out = client.complete(request);
            synchronized (this) { consecutiveFailures = 0; }
            return out;
        } catch (LlmException e) {
            // Bad output / local limit say nothing about provider health; transport and auth failures do.
            if (e.kind() != Kind.BAD_OUTPUT) {
                synchronized (this) {
                    if (++consecutiveFailures >= BREAKER_THRESHOLD) {
                        openUntil = System.currentTimeMillis() + BREAKER_OPEN_MS;
                        consecutiveFailures = 0;
                    }
                }
            }
            throw e;
        }
    }
}

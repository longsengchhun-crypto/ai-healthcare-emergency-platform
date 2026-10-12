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
    public static final String PROVIDER_GEMINI = "gemini";
    private static final int BREAKER_THRESHOLD = 3;
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
        if (externalRequested()) {
            c = injected.getIfAvailable();
            if (c == null && ai.apiKey() != null && !ai.apiKey().isBlank()) {
                String key = ai.apiKey().trim();
                boolean blankModel = ai.model() == null || ai.model().isBlank();
                Duration timeout = Duration.ofSeconds(ai.timeoutSeconds() > 0 ? ai.timeoutSeconds() : 20);
                int retries = Math.max(0, ai.maxRetries());
                if (PROVIDER_GEMINI.equals(providerName)) {
                    c = new GeminiLlmClient(key, geminiModels(blankModel ? "" : ai.model().trim()), timeout, retries,
                            ai.baseUrl());
                } else {
                    c = new AnthropicLlmClient(key, blankModel ? "claude-opus-5-5" : ai.model().trim(), timeout,
                            retries, ai.baseUrl());
                }
            }
        }
        this.client = c;
    }

    /**
     * Calls the model and parses/validates the answer. If the answer is unusable (malformed or rejected by a safety
     * guard) it asks once more: model wording varies between runs and a second sample usually passes. The retry uses
     * the same per-user rate limit; if it also fails the caller falls back to the deterministic result.
     */
    public <T> T completeParsed(UUID userId, LlmClient.Request request, java.util.function.Function<String, T> parser) {
        try {
            return parser.apply(complete(userId, request));
        } catch (LlmException e) {
            if (e.kind() != Kind.BAD_OUTPUT) throw e;
        }
        return parser.apply(complete(userId, request));
    }

    /** Free-tier models tried in order; each has its own small daily quota, so falling through extends capacity. */
    static final java.util.List<String> GEMINI_DEFAULTS = java.util.List.of(
            "gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite");

    /** Configured model first, then the defaults not already listed; an explicit comma list is used as given. */
    static String geminiModels(String configured) {
        if (configured.contains(",")) return configured;
        java.util.List<String> out = new java.util.ArrayList<>();
        if (!configured.isBlank()) out.add(configured);
        for (String m : GEMINI_DEFAULTS) if (!out.contains(m)) out.add(m);
        return String.join(",", out);
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
    public boolean externalRequested() {
        return PROVIDER_ANTHROPIC.equals(providerName) || PROVIDER_GEMINI.equals(providerName);
    }

    /** Name of the provider actually answering requests ("deterministic-demo" when no model is available). */
    public String providerName() { return configured() ? providerName : "deterministic-demo"; }

    public String displayName() { return PROVIDER_GEMINI.equals(providerName) ? "Gemini" : "Claude"; }

    /**
     * True for the free Gemini tier, whose terms allow submitted content to be used to improve the provider's
     * products (https://ai.google.dev/gemini-api/docs/pricing). Callers must obtain consent before sending records.
     */
    public boolean providerMayUseDataForTraining() { return PROVIDER_GEMINI.equals(providerName); }

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

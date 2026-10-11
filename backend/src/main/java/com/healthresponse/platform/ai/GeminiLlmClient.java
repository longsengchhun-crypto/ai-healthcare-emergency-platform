package com.healthresponse.platform.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Google Gemini provider (REST {@code models/{model}:generateContent}), usable on Google's free API tier.
 * Reads PDFs and images natively (inlineData). The key is sent in the {@code x-goog-api-key} header, never in the URL.
 * Retries only server errors and connection failures; a 429 (quota) is returned at once because retrying a daily
 * free-tier quota cannot succeed. Never logs prompts, responses or exception messages.
 */
public class GeminiLlmClient implements LlmClient {
    private static final Logger LOG = LoggerFactory.getLogger(GeminiLlmClient.class);
    private static final ObjectMapper JSON = new ObjectMapper();
    public static final String DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com";

    private final HttpClient http;
    private final String apiKey;
    private final String model;
    private final String baseUrl;
    private final Duration timeout;
    private final int maxRetries;

    public GeminiLlmClient(String apiKey, String model, Duration timeout, int maxRetries, String baseUrlOrNull) {
        this.apiKey = apiKey;
        this.model = model;
        this.timeout = timeout;
        this.maxRetries = Math.max(0, maxRetries);
        this.baseUrl = baseUrlOrNull == null || baseUrlOrNull.isBlank() ? DEFAULT_BASE_URL
                : baseUrlOrNull.replaceAll("/+$", "");
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    @Override
    public String complete(Request r) {
        String payload = buildBody(r);
        URI uri = URI.create(baseUrl + "/v1beta/models/" + model + ":generateContent");
        LlmException last = new LlmException(LlmException.Kind.UNAVAILABLE, "AI provider call failed");
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            if (attempt > 0) {
                try {
                    Thread.sleep(400L * (1L << (attempt - 1)));
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new LlmException(LlmException.Kind.UNAVAILABLE, "interrupted");
                }
            }
            try {
                HttpRequest req = HttpRequest.newBuilder(uri).timeout(timeout)
                        .header("content-type", "application/json")
                        .header("x-goog-api-key", apiKey)
                        .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8)).build();
                HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                int code = res.statusCode();
                if (code == 200) return extractText(res.body());
                last = mapError(code, res.body());
                LOG.warn("AI provider (gemini) HTTP {}", code);
                if (code < 500) throw last; // 4xx are not retried
            } catch (HttpTimeoutException e) {
                LOG.warn("AI provider (gemini) timeout");
                last = new LlmException(LlmException.Kind.TIMEOUT, "AI provider timed out");
            } catch (IOException e) {
                LOG.warn("AI provider (gemini) connection problem");
                last = new LlmException(LlmException.Kind.UNAVAILABLE, "AI provider connection problem");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new LlmException(LlmException.Kind.UNAVAILABLE, "interrupted");
            }
        }
        throw last;
    }

    private String buildBody(Request r) {
        ObjectNode body = JSON.createObjectNode();
        body.putObject("systemInstruction").putArray("parts").addObject().put("text", r.system());
        ArrayNode parts = body.putArray("contents").addObject().put("role", "user").putArray("parts");
        if (r.attachment() != null) {
            ObjectNode inline = parts.addObject().putObject("inlineData");
            inline.put("mimeType", r.attachment().mediaType());
            inline.put("data", Base64.getEncoder().encodeToString(r.attachment().bytes()));
        }
        parts.addObject().put("text", r.userText());
        ObjectNode cfg = body.putObject("generationConfig");
        cfg.put("responseMimeType", "application/json");
        cfg.put("temperature", 0.2);
        // Gemini 2.5+ "thinking" tokens count against this limit, so leave generous room for the answer itself.
        cfg.put("maxOutputTokens", Math.max(r.maxTokens(), 8192));
        return body.toString();
    }

    private static String extractText(String raw) {
        JsonNode root;
        try {
            root = JSON.readTree(raw);
        } catch (IOException e) {
            throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider returned unreadable data");
        }
        if (root == null || root.path("promptFeedback").hasNonNull("blockReason")) {
            throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider blocked the request");
        }
        JsonNode cand = root.path("candidates").path(0);
        String finish = cand.path("finishReason").asText("STOP");
        if (!finish.equals("STOP")) {
            throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider did not complete the answer");
        }
        StringBuilder sb = new StringBuilder();
        for (JsonNode part : cand.path("content").path("parts")) {
            if (part.path("thought").asBoolean(false)) continue;
            if (part.hasNonNull("text")) sb.append(part.get("text").asText());
        }
        if (sb.toString().isBlank()) throw new LlmException(LlmException.Kind.BAD_OUTPUT, "AI provider returned no text");
        return sb.toString();
    }

    private static LlmException mapError(int code, String body) {
        if (code == 401 || code == 403) return new LlmException(LlmException.Kind.AUTH, "AI provider rejected the credentials");
        if (code == 429) return new LlmException(LlmException.Kind.RATE_LIMITED, "AI provider quota reached");
        if (code == 400) {
            // Google reports an invalid key as 400 INVALID_ARGUMENT ("API key not valid") rather than 401.
            String lower = body == null ? "" : body.toLowerCase();
            if (lower.contains("api key not valid") || lower.contains("api_key_invalid")) {
                return new LlmException(LlmException.Kind.AUTH, "AI provider rejected the credentials");
            }
        }
        return new LlmException(LlmException.Kind.UNAVAILABLE, "AI provider error");
    }
}

package com.healthresponse.platform.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.healthresponse.platform.ai.LlmClient.LlmException;
import com.healthresponse.platform.ai.LlmClient.LlmException.Kind;
import com.healthresponse.platform.security.AppProperties;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;

/** The Gemini provider against a local fake HTTP server: no network, no key, no cost. */
class GeminiLlmClientTest {
    HttpServer server;
    final AtomicInteger status = new AtomicInteger(200);
    final AtomicInteger hits = new AtomicInteger();
    final AtomicReference<String> body = new AtomicReference<>();
    final AtomicReference<String> lastRequest = new AtomicReference<>("");
    final AtomicReference<String> lastPath = new AtomicReference<>("");
    final AtomicReference<String> lastKey = new AtomicReference<>("");
    final AtomicInteger delayMs = new AtomicInteger();

    static final String OK = """
            {"candidates":[{"content":{"role":"model","parts":[{"text":"{\\"ok\\":true}"}]},"finishReason":"STOP"}],
             "usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4}}""";

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            hits.incrementAndGet();
            lastPath.set(ex.getRequestURI().toString());
            lastKey.set(String.valueOf(ex.getRequestHeaders().getFirst("x-goog-api-key")));
            lastRequest.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            if (delayMs.get() > 0) {
                try { Thread.sleep(delayMs.get()); } catch (InterruptedException ignored) { /* test */ }
            }
            byte[] out = body.get().getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("content-type", "application/json");
            ex.sendResponseHeaders(status.get(), out.length);
            ex.getResponseBody().write(out);
            ex.close();
        });
        server.start();
        body.set(OK);
    }

    @AfterEach
    void stop() { server.stop(0); }

    GeminiLlmClient client(int retries, int timeoutSeconds) {
        return new GeminiLlmClient("test-key-not-real", "gemini-2.5-flash", Duration.ofSeconds(timeoutSeconds), retries,
                "http://127.0.0.1:" + server.getAddress().getPort());
    }

    LlmClient.Request req() { return new LlmClient.Request("system rules", "hello", 512); }

    @Test
    void sendsKeyInHeaderNotUrlAndReturnsText() {
        assertThat(client(0, 5).complete(req())).isEqualTo("{\"ok\":true}");
        assertThat(lastPath.get()).isEqualTo("/v1beta/models/gemini-2.5-flash:generateContent").doesNotContain("key");
        assertThat(lastKey.get()).isEqualTo("test-key-not-real");
        assertThat(lastRequest.get()).contains("systemInstruction").contains("system rules").contains("hello")
                .contains("\"responseMimeType\":\"application/json\"");
    }

    @Test
    void pdfAndImagesAreSentAsInlineData() {
        client(0, 5).complete(new LlmClient.Request("s", "read", new LlmClient.Attachment("application/pdf",
                "%PDF-1.4".getBytes(StandardCharsets.ISO_8859_1)), 256));
        assertThat(lastRequest.get()).contains("inlineData").contains("application/pdf");
        client(0, 5).complete(new LlmClient.Request("s", "read", new LlmClient.Attachment("image/png", new byte[] {1, 2}), 256));
        assertThat(lastRequest.get()).contains("image/png");
    }

    @Test
    void failureClassesAreMapped() {
        record Case(int http, String payload, Kind kind) {}
        String err = "{\"error\":{\"code\":%d,\"message\":\"%s\",\"status\":\"X\"}}";
        for (Case c : new Case[] {
                new Case(401, err.formatted(401, "bad"), Kind.AUTH),
                new Case(403, err.formatted(403, "denied"), Kind.AUTH),
                new Case(400, err.formatted(400, "API key not valid. Please pass a valid API key."), Kind.AUTH),
                new Case(400, err.formatted(400, "something else"), Kind.UNAVAILABLE),
                new Case(429, err.formatted(429, "quota"), Kind.RATE_LIMITED),
                new Case(500, err.formatted(500, "boom"), Kind.UNAVAILABLE)}) {
            status.set(c.http());
            body.set(c.payload());
            assertThatThrownBy(() -> client(0, 5).complete(req()))
                    .isInstanceOfSatisfying(LlmException.class,
                            e -> assertThat(e.kind()).as("HTTP " + c.http() + " " + c.payload()).isEqualTo(c.kind()));
        }
    }

    @Test
    void quotaErrorsAreNotRetriedButServerErrorsAre() {
        status.set(429);
        body.set("{\"error\":{\"code\":429,\"message\":\"quota\"}}");
        assertThatThrownBy(() -> client(2, 5).complete(req())).isInstanceOf(LlmException.class);
        assertThat(hits.get()).isEqualTo(1);

        hits.set(0);
        server.removeContext("/");
        server.createContext("/", ex -> {
            int n = hits.incrementAndGet();
            ex.getRequestBody().readAllBytes();
            byte[] out = (n == 1 ? "{\"error\":{\"code\":503}}" : OK).getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("content-type", "application/json");
            ex.sendResponseHeaders(n == 1 ? 503 : 200, out.length);
            ex.getResponseBody().write(out);
            ex.close();
        });
        assertThat(client(2, 5).complete(req())).isEqualTo("{\"ok\":true}");
        assertThat(hits.get()).isEqualTo(2);
    }

    @Test
    void slowProviderIsCutOffByTheTimeout() {
        delayMs.set(3000);
        long t0 = System.currentTimeMillis();
        assertThatThrownBy(() -> client(0, 1).complete(req()))
                .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).isEqualTo(Kind.TIMEOUT));
        assertThat(System.currentTimeMillis() - t0).isLessThan(2900);
    }

    @Test
    void blockedTruncatedAndEmptyAnswersAreBadOutput() {
        for (String payload : new String[] {
                "{\"promptFeedback\":{\"blockReason\":\"SAFETY\"}}",
                OK.replace("\"STOP\"", "\"MAX_TOKENS\""),
                OK.replace("\"STOP\"", "\"SAFETY\""),
                "{\"candidates\":[{\"content\":{\"parts\":[]},\"finishReason\":\"STOP\"}]}",
                "not json"}) {
            body.set(payload);
            assertThatThrownBy(() -> client(0, 5).complete(req()))
                    .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).isEqualTo(Kind.BAD_OUTPUT));
        }
    }

    @Test
    void thoughtPartsAreNotReturnedAsAnswer() {
        body.set("{\"candidates\":[{\"content\":{\"parts\":[{\"thought\":true,\"text\":\"internal\"},"
                + "{\"text\":\"{\\\"a\\\":1}\"}]},\"finishReason\":\"STOP\"}]}");
        assertThat(client(0, 5).complete(req())).isEqualTo("{\"a\":1}");
    }

    @Test
    void gatewaySelectsGeminiAndDefaultsTheModel() {
        AppProperties props = new AppProperties(null, null, null, null,
                new AppProperties.Ai("gemini", "k", "", 5, 0, 10, "http://127.0.0.1:" + server.getAddress().getPort()),
                null, null);
        LlmGateway gw = new LlmGateway(props, new DefaultListableBeanFactory().getBeanProvider(LlmClient.class));
        assertThat(gw.configured()).isTrue();
        assertThat(gw.providerName()).isEqualTo("gemini");
        assertThat(gw.providerMayUseDataForTraining()).isTrue();
        gw.complete(java.util.UUID.randomUUID(), req());
        assertThat(lastPath.get()).contains("gemini-2.5-flash");

        AppProperties none = new AppProperties(null, null, null, null,
                new AppProperties.Ai("gemini", "", "", 5, 0, 10, null), null, null);
        LlmGateway off = new LlmGateway(none, new DefaultListableBeanFactory().getBeanProvider(LlmClient.class));
        assertThat(off.configured()).isFalse();
        assertThat(off.providerName()).isEqualTo("deterministic-demo");
    }
}

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

/**
 * Exercises the real Anthropic SDK client against a local fake HTTP server (no network, no cost): request shape,
 * header, and mapping of every failure class.
 */
class AnthropicLlmClientTest {
    HttpServer server;
    final AtomicInteger status = new AtomicInteger(200);
    final AtomicInteger hits = new AtomicInteger();
    final AtomicReference<String> body = new AtomicReference<>("");
    final AtomicReference<String> lastRequest = new AtomicReference<>("");
    final AtomicReference<String> lastKey = new AtomicReference<>("");
    final AtomicInteger delayMs = new AtomicInteger();

    static final String OK = """
            {"id":"msg_test","type":"message","role":"assistant","model":"claude-opus-5-5",
             "content":[{"type":"text","text":"{\\"ok\\":true}"}],"stop_reason":"end_turn","stop_sequence":null,
             "usage":{"input_tokens":3,"output_tokens":4}}""";

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            hits.incrementAndGet();
            lastKey.set(String.valueOf(ex.getRequestHeaders().getFirst("x-api-key")));
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

    AnthropicLlmClient client(int retries, int timeoutSeconds) {
        return new AnthropicLlmClient("test-key-not-real", "claude-opus-5-5", Duration.ofSeconds(timeoutSeconds),
                retries, "http://127.0.0.1:" + server.getAddress().getPort());
    }

    LlmClient.Request req() { return new LlmClient.Request("system rules", "hello", 512); }

    @Test
    void sendsModelKeySystemAndUserTextAndReturnsTheModelText() {
        String out = client(0, 5).complete(req());
        assertThat(out).isEqualTo("{\"ok\":true}");
        assertThat(lastKey.get()).isEqualTo("test-key-not-real");
        assertThat(lastRequest.get()).contains("claude-opus-5-5").contains("system rules").contains("hello")
                .contains("\"max_tokens\":512");
    }

    @Test
    void pdfAndImageAttachmentsAreSentAsDocumentAndImageBlocks() {
        client(0, 5).complete(new LlmClient.Request("s", "read", new LlmClient.Attachment("application/pdf",
                "%PDF-1.4".getBytes(StandardCharsets.ISO_8859_1)), 256));
        assertThat(lastRequest.get()).contains("\"type\":\"document\"").contains("application/pdf");
        client(0, 5).complete(new LlmClient.Request("s", "read", new LlmClient.Attachment("image/png", new byte[] {1, 2, 3}), 256));
        assertThat(lastRequest.get()).contains("\"type\":\"image\"").contains("image/png");
    }

    @Test
    void failureClassesAreMappedAndNeverReturnText() {
        record Case(int http, Kind kind) {}
        for (Case c : new Case[] {new Case(401, Kind.AUTH), new Case(403, Kind.AUTH), new Case(429, Kind.RATE_LIMITED),
                new Case(500, Kind.UNAVAILABLE), new Case(400, Kind.UNAVAILABLE)}) {
            status.set(c.http());
            body.set("{\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"boom\"}}");
            assertThatThrownBy(() -> client(0, 5).complete(req()))
                    .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).as("HTTP " + c.http()).isEqualTo(c.kind()));
        }
    }

    @Test
    void transientErrorsAreRetriedAndThenSucceed() {
        status.set(200);
        // first request 500, then OK: handler switches after the first hit
        server.removeContext("/");
        server.createContext("/", ex -> {
            int n = hits.incrementAndGet();
            ex.getRequestBody().readAllBytes();
            byte[] out = (n == 1 ? "{\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"x\"}}" : OK)
                    .getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("content-type", "application/json");
            ex.sendResponseHeaders(n == 1 ? 500 : 200, out.length);
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
                .isInstanceOfSatisfying(LlmException.class,
                        e -> assertThat(e.kind()).isIn(Kind.TIMEOUT, Kind.UNAVAILABLE));
        assertThat(System.currentTimeMillis() - t0).isLessThan(2900);
    }

    @Test
    void refusalAndTruncationAreTreatedAsBadOutput() {
        body.set(OK.replace("\"end_turn\"", "\"refusal\""));
        assertThatThrownBy(() -> client(0, 5).complete(req()))
                .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).isEqualTo(Kind.BAD_OUTPUT));
        body.set(OK.replace("\"end_turn\"", "\"max_tokens\""));
        assertThatThrownBy(() -> client(0, 5).complete(req()))
                .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).isEqualTo(Kind.BAD_OUTPUT));
    }

    @Test
    void circuitBreakerOpensAfterRepeatedProviderFailuresAndStopsCallingIt() {
        AtomicInteger calls = new AtomicInteger();
        LlmClient failing = r -> {
            calls.incrementAndGet();
            throw new LlmException(Kind.UNAVAILABLE, "down");
        };
        DefaultListableBeanFactory bf = new DefaultListableBeanFactory();
        bf.registerSingleton("failing", failing);
        AppProperties props = new AppProperties(null, null, null, null,
                new AppProperties.Ai("anthropic", "", "m", 5, 0, 100, null), null, null);
        LlmGateway gw = new LlmGateway(props, bf.getBeanProvider(LlmClient.class));
        java.util.UUID u = java.util.UUID.randomUUID();
        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> gw.complete(u, req())).isInstanceOf(LlmException.class);
        }
        assertThatThrownBy(() -> gw.complete(u, req()))
                .isInstanceOfSatisfying(LlmException.class, e -> assertThat(e.kind()).isEqualTo(Kind.CIRCUIT_OPEN));
        assertThat(calls.get()).isEqualTo(5);
    }
}

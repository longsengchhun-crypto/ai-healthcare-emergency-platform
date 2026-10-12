package com.healthresponse.platform.config;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Free Render web services go to sleep after 15 minutes without inbound traffic, and the next visitor sees Render's
 * "APPLICATION LOADING" page for ~45 s. While the service is awake it requests its own public URL every 9 minutes
 * (the request goes out through Render's proxy, so it counts as traffic). Inactive unless RENDER_EXTERNAL_URL (set by
 * Render automatically) or KEEPALIVE_URL is present, so local runs and tests never make the call.
 *
 * This cannot wake a service that is already asleep - an external pinger still has to do that (docs/CLOUD_DEPLOY.md).
 */
@Component
public class SelfKeepAlive {
    private static final Logger log = LoggerFactory.getLogger(SelfKeepAlive.class);
    private final String target;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    public SelfKeepAlive(@Value("${KEEPALIVE_URL:${RENDER_EXTERNAL_URL:}}") String baseUrl) {
        String base = baseUrl == null ? "" : baseUrl.strip();
        this.target = base.isEmpty() ? null : base.replaceAll("/+$", "") + "/actuator/health/liveness";
        if (target != null) log.info("Self keep-alive enabled -> {}", target);
    }

    @Scheduled(initialDelay = 240_000, fixedDelay = 540_000)
    public void ping() {
        if (target == null) return;
        try {
            HttpResponse<Void> r = http.send(
                    HttpRequest.newBuilder(URI.create(target)).timeout(Duration.ofSeconds(20)).GET().build(),
                    HttpResponse.BodyHandlers.discarding());
            log.debug("Self keep-alive -> HTTP {}", r.statusCode());
        } catch (Exception e) {
            log.warn("Self keep-alive failed: {}", e.toString());
        }
    }
}

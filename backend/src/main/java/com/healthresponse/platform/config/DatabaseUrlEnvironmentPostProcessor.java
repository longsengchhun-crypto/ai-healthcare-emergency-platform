package com.healthresponse.platform.config;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

/**
 * Hosting platforms (Render, Neon, Heroku, Railway ...) hand out a single DATABASE_URL such as
 * {@code postgres://user:pass@host:5432/db?sslmode=require}. JDBC needs a different shape, so when DATABASE_URL is
 * present and DB_URL is not, translate it into the spring.datasource.* properties. Credentials are never logged.
 */
@Order(Ordered.LOWEST_PRECEDENCE - 10)
public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment env, SpringApplication app) {
        String raw = env.getProperty("DATABASE_URL");
        if (raw == null || raw.isBlank() || env.getProperty("DB_URL") != null) return;
        Map<String, Object> props = translate(raw.trim());
        if (!props.isEmpty()) {
            env.getPropertySources().addFirst(new MapPropertySource("databaseUrl", props));
        }
    }

    /** Package-visible for tests. */
    static Map<String, Object> translate(String raw) {
        Map<String, Object> out = new HashMap<>();
        if (raw.startsWith("jdbc:")) {
            out.put("spring.datasource.url", raw);
            return out;
        }
        URI uri = URI.create(raw);
        String scheme = uri.getScheme();
        if (scheme == null || !(scheme.equals("postgres") || scheme.equals("postgresql"))) return out;
        int port = uri.getPort() == -1 ? 5432 : uri.getPort();
        String query = uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery();
        out.put("spring.datasource.url", "jdbc:postgresql://" + uri.getHost() + ":" + port + uri.getRawPath() + query);
        String userInfo = uri.getUserInfo();
        if (userInfo != null) {
            int colon = userInfo.indexOf(':');
            String user = colon < 0 ? userInfo : userInfo.substring(0, colon);
            String pass = colon < 0 ? "" : userInfo.substring(colon + 1);
            out.put("spring.datasource.username", java.net.URLDecoder.decode(user, java.nio.charset.StandardCharsets.UTF_8));
            out.put("spring.datasource.password", java.net.URLDecoder.decode(pass, java.nio.charset.StandardCharsets.UTF_8));
        }
        return out;
    }
}

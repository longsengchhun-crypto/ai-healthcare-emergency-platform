package com.healthresponse.platform;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import java.io.IOException;
import org.springframework.test.context.DynamicPropertyRegistry;

/** One embedded real PostgreSQL server shared by all *PostgresTest classes (no Docker required). */
final class PostgresSupport {
    private static EmbeddedPostgres pg;

    private PostgresSupport() {}

    static synchronized void register(DynamicPropertyRegistry registry) throws IOException {
        if (pg == null) {
            pg = EmbeddedPostgres.builder().start();
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                try { pg.close(); } catch (IOException ignored) { }
            }));
        }
        registry.add("spring.datasource.url", () -> pg.getJdbcUrl("postgres", "postgres"));
        registry.add("spring.datasource.username", () -> "postgres");
        registry.add("spring.datasource.password", () -> "");
    }
}

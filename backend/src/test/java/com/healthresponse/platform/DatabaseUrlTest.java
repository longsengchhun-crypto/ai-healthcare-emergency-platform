package com.healthresponse.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Method;
import java.util.Map;
import org.junit.jupiter.api.Test;

class DatabaseUrlTest {
    @SuppressWarnings("unchecked")
    private Map<String, Object> translate(String raw) throws Exception {
        Class<?> c = Class.forName("com.healthresponse.platform.config.DatabaseUrlEnvironmentPostProcessor");
        Method m = c.getDeclaredMethod("translate", String.class);
        m.setAccessible(true);
        return (Map<String, Object>) m.invoke(null, raw);
    }

    @Test
    void translatesPlatformStylePostgresUrl() throws Exception {
        Map<String, Object> p = translate("postgres://healthapp:p%40ss:word@dpg-abc.oregon-postgres.render.com/healthplatform?sslmode=require");
        assertThat(p.get("spring.datasource.url"))
                .isEqualTo("jdbc:postgresql://dpg-abc.oregon-postgres.render.com:5432/healthplatform?sslmode=require");
        assertThat(p.get("spring.datasource.username")).isEqualTo("healthapp");
        assertThat(p.get("spring.datasource.password")).isEqualTo("p@ss:word");
    }

    @Test
    void keepsExplicitPortAndJdbcUrls() throws Exception {
        assertThat(translate("postgresql://u:p@host:6543/db").get("spring.datasource.url"))
                .isEqualTo("jdbc:postgresql://host:6543/db");
        assertThat(translate("jdbc:postgresql://h/db").get("spring.datasource.url")).isEqualTo("jdbc:postgresql://h/db");
        assertThat(translate("mysql://u:p@h/db")).isEmpty();
    }
}

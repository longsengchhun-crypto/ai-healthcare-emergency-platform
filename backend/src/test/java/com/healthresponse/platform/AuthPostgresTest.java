package com.healthresponse.platform;

import java.io.IOException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/** Authentication, refresh rotation and reuse detection against real PostgreSQL. */
class AuthPostgresTest extends AuthIntegrationTest {
    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) throws IOException { PostgresSupport.register(registry); }
}

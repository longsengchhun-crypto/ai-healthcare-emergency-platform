package com.healthresponse.platform;

import java.io.IOException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/** Record isolation, uploads, AI and reminders against real PostgreSQL. */
class SecurityRecordsPostgresTest extends SecurityAndRecordsIntegrationTest {
    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) throws IOException { PostgresSupport.register(registry); }
}

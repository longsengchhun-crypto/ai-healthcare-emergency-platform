package com.healthresponse.platform;

import java.io.IOException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/** Appointment + emergency flows against real PostgreSQL (validates Flyway migrations and SQL on PostgreSQL). */
class FlowPostgresTest extends FlowIntegrationTest {
    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) throws IOException { PostgresSupport.register(registry); }
}

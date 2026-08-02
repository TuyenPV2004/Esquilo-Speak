package com.esquilospeak;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false",
    "esquilospeak.operations.retention-enabled=false"
})
class BackendReleaseGateIntegrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer(DockerImageName.parse("postgres:18-alpine"));

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    JdbcClient jdbc;

    @Test
    void migratesPostgresql18FromBaselineThroughCurrentVersion() {
        List<String> appliedVersions = jdbc.sql("""
                        select version
                        from flyway_schema_history
                        where success
                        order by installed_rank
                        """)
                .query(String.class)
                .list();

        assertEquals(
                List.of(
                        "1", "2", "3", "4", "5", "6", "7",
                        "8", "9", "10", "11", "12", "13", "14"),
                appliedVersions);
        assertEquals(
                7,
                jdbc.sql("""
                                select count(*)
                                from information_schema.tables
                                where table_schema = 'public'
                                  and table_name in (
                                    'learners',
                                    'course_versions',
                                    'attempts',
                                    'mastery_states',
                                    'operational_audit_events',
                                    'advanced_feedback_results',
                                    'daily_learning_policies'
                                  )
                                """)
                        .query(Integer.class)
                        .single());
    }
}

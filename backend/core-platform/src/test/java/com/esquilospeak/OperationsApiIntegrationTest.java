package com.esquilospeak;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.sql.DriverManager;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.micrometer.metrics.test.autoconfigure.AutoConfigureMetrics;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false",
    "esquilospeak.operations.retention-enabled=false",
    "esquilospeak.rate-limit.attempts-per-minute=2"
})
@AutoConfigureMetrics
@AutoConfigureMockMvc
class OperationsApiIntegrationTest {

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
    MockMvc mockMvc;

    @Autowired
    JdbcClient jdbc;

    @Test
    void exposesProbesButProtectsPrometheusWithOperationsAuthority() throws Exception {
        mockMvc.perform(get("/livez")).andExpect(status().isOk());
        mockMvc.perform(get("/readyz")).andExpect(status().isOk());

        mockMvc.perform(get("/actuator/prometheus")
                        .header("X-Correlation-ID", "metrics-unauthorized"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.traceId").value("metrics-unauthorized"));

        mockMvc.perform(get("/actuator/prometheus").with(learnerJwt("metrics-learner")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));

        String scrape = mockMvc.perform(get("/actuator/prometheus")
                        .with(operationsJwt("metrics-operator")))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertTrue(scrape.contains("http_server_requests"));
        assertTrue(scrape.contains("application=\"esquilospeak-core-platform\""));
    }

    @Test
    void rateLimitsExpensiveWritesAndAuditsOnlyPseudonymousActor() throws Exception {
        String subject = "rate-limit-subject-" + UUID.randomUUID();
        for (int index = 0; index < 2; index++) {
            mockMvc.perform(post("/api/mobile/v1/attempts")
                            .with(learnerJwt(subject))
                            .header("Idempotency-Key", UUID.randomUUID())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(attemptJson(UUID.randomUUID())))
                    .andExpect(status().isOk())
                    .andExpect(header().exists("RateLimit-Policy"));
        }

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(learnerJwt(subject))
                        .header("X-Correlation-ID", "rate-limit-test")
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.code").value("RATE_LIMIT_EXCEEDED"))
                .andExpect(jsonPath("$.retryable").value(true));

        AuditRow event = jdbc.sql("""
                        select actor_hash, metadata::text
                        from operational_audit_events
                        where action = 'RATE_LIMIT_EXCEEDED'
                        order by occurred_at desc
                        limit 1
                        """)
                .query((rs, rowNum) ->
                        new AuditRow(rs.getString("actor_hash"), rs.getString("metadata")))
                .single();
        assertEquals(64, event.actorHash().length());
        assertFalse(event.metadata().contains(subject));
        assertTrue(event.metadata().contains("attempt-submit"));
    }

    @Test
    void auditsDeniedSecurityAndFailedAdminMutationWithoutRequestPayload() throws Exception {
        String subject = "admin-audit-subject-" + UUID.randomUUID();
        mockMvc.perform(get("/actuator/prometheus").with(learnerJwt(subject)))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/admin/v1/content/courses/course-invalid/versions/2")
                        .with(contentAdminJwt(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());

        List<AuditRow> events = jdbc.sql("""
                        select actor_hash, metadata::text
                        from operational_audit_events
                        where action in ('SECURITY_ACCESS_REJECTED', 'ADMIN_HTTP_MUTATION')
                        order by occurred_at
                        """)
                .query((rs, rowNum) ->
                        new AuditRow(rs.getString("actor_hash"), rs.getString("metadata")))
                .list();
        assertTrue(events.size() >= 2);
        assertTrue(events.stream().allMatch(event -> event.actorHash().length() == 64));
        assertTrue(events.stream().noneMatch(event -> event.metadata().contains(subject)));
        assertTrue(events.stream().noneMatch(event -> event.metadata().contains("{}")));
    }

    @Test
    void performsPostgresqlBackupRestoreDrillFromMigratedSchema() throws Exception {
        String sourceDatabase = POSTGRES.getDatabaseName();
        String user = POSTGRES.getUsername();
        String restoredDatabase = "esquilospeak_restore_drill";
        var result = POSTGRES.execInContainer(
                "sh",
                "-c",
                """
                set -eu
                pg_dump -U "$1" -d "$2" -Fc -f /tmp/esquilospeak.dump
                dropdb --if-exists -U "$1" "$3"
                createdb -U "$1" "$3"
                pg_restore -U "$1" -d "$3" --no-owner --no-privileges /tmp/esquilospeak.dump
                rm -f /tmp/esquilospeak.dump
                """,
                "backup-restore-drill",
                user,
                sourceDatabase,
                restoredDatabase);
        assertEquals(0, result.getExitCode(), result.getStderr());

        try (var connection = DriverManager.getConnection(
                        jdbcUrlFor(restoredDatabase),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword());
                var statement = connection.createStatement()) {
            try (var versions = statement.executeQuery(
                    "select max(version::integer) from flyway_schema_history where success")) {
                assertTrue(versions.next());
                assertEquals(15, versions.getInt(1));
            }
            try (var tables = statement.executeQuery("""
                    select count(*)
                    from information_schema.tables
                    where table_schema = 'public'
                      and table_name in (
                        'learners', 'course_versions', 'attempts',
                        'mastery_states', 'operational_audit_events'
                      )
                    """)) {
                assertTrue(tables.next());
                assertEquals(5, tables.getInt(1));
            }
        }
    }

    private String jdbcUrlFor(String database) {
        String source = POSTGRES.getJdbcUrl();
        int query = source.indexOf('?');
        String suffix = query < 0 ? "" : source.substring(query);
        String withoutQuery = query < 0 ? source : source.substring(0, query);
        return withoutQuery.substring(0, withoutQuery.lastIndexOf('/') + 1) + database + suffix;
    }

    private String attemptJson(UUID clientAttemptId) {
        return """
                {
                  "clientAttemptId": "%s",
                  "courseId": "course-en-for-vi",
                  "lessonId": "lesson-basic-greetings",
                  "lessonVersion": 1,
                  "exerciseId": "exercise-choose-hello",
                  "selectedOptionId": "option-hello",
                  "occurredAt": "%s",
                  "responseTimeMs": 250
                }
                """.formatted(clientAttemptId, Instant.now());
    }

    private RequestPostProcessor learnerJwt(String subject) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", List.of("learner")))
                .authorities(
                        new SimpleGrantedAuthority("ROLE_LEARNER"),
                        new SimpleGrantedAuthority("SCOPE_learning"));
    }

    private RequestPostProcessor operationsJwt(String subject) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "operations")
                        .claim("roles", List.of("support")))
                .authorities(
                        new SimpleGrantedAuthority("ROLE_SUPPORT"),
                        new SimpleGrantedAuthority("SCOPE_operations"));
    }

    private RequestPostProcessor contentAdminJwt(String subject) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "content")
                        .claim("roles", List.of("admin")))
                .authorities(
                        new SimpleGrantedAuthority("ROLE_ADMIN"),
                        new SimpleGrantedAuthority("SCOPE_content"));
    }

    private record AuditRow(String actorHash, String metadata) {}
}

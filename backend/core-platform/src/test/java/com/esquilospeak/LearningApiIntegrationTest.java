package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.Clock;
import java.time.Duration;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicReference;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false"
})
@AutoConfigureMockMvc
@Import(LearningApiIntegrationTest.ClockTestConfiguration.class)
class LearningApiIntegrationTest {

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

    @Autowired
    MutableClock clock;

    @Test
    void servesCatalogAndLearnerSafeLesson() throws Exception {
        mockMvc.perform(post("/internal/dev/token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty());

        mockMvc.perform(get("/api/mobile/v1/languages"))
                .andExpect(header().exists("X-Correlation-ID"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].languageTag").exists());

        mockMvc.perform(get("/api/mobile/v1/courses")
                        .param("sourceLanguage", "vi")
                        .param("targetLanguage", "en"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value("course-en-for-vi"))
                .andExpect(jsonPath("$.items[0].version").value(1))
                .andExpect(jsonPath("$.items[0].unitIds[0]").value("unit-foundation"));

        mockMvc.perform(get("/api/mobile/v1/courses/course-en-for-vi/lessons"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value("lesson-basic-greetings"))
                .andExpect(jsonPath("$.items[0].unitId").value("unit-foundation"))
                .andExpect(jsonPath("$.items[0].unitTitle.en").value("Foundation"))
                .andExpect(jsonPath("$.items[0].position").value(1));

        mockMvc.perform(get("/api/mobile/v1/lessons/lesson-basic-greetings"))
                .andExpect(status().isOk())
                .andExpect(header().exists("ETag"))
                .andExpect(jsonPath("$.version").value(1))
                .andExpect(jsonPath("$.courseVersion").value(1))
                .andExpect(jsonPath("$.unitId").value("unit-foundation"))
                .andExpect(jsonPath("$.locale").value("vi"))
                .andExpect(jsonPath("$.exercises[0].correctOptionId").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].correctAnswer").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].explanation").doesNotExist());

        mockMvc.perform(get("/api/mobile/v1/progress/courses/course-en-for-vi"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void submitsIdempotentAttemptAndUpdatesProgressOnlyWhenCorrect() throws Exception {
        UUID clientAttemptId = UUID.randomUUID();
        UUID idempotencyKey = UUID.randomUUID();
        String request = attemptJson(clientAttemptId, "option-hello");

        String response = mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guestJwt("learner-integration"))
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.correct").value(true))
                .andExpect(jsonPath("$.feedback.correctOptionId").value("option-hello"))
                .andExpect(jsonPath("$.progress.completedExerciseCount").value(1))
                .andExpect(jsonPath("$.syncCursor").value(
                        org.hamcrest.Matchers.startsWith("v1.")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guestJwt("learner-integration"))
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.attemptId")
                        .value(toJsonField(response, "attemptId")));

        mockMvc.perform(get("/api/mobile/v1/progress/courses/course-en-for-vi")
                        .with(guestJwt("learner-integration")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completedExerciseCount").value(1))
                .andExpect(jsonPath("$.lessonProgress[0].status").value("completed"));
        String evidence = jdbc.sql("select evidence::text from attempts where client_attempt_id = :id")
                .param("id", clientAttemptId)
                .query(String.class)
                .single();
        org.junit.jupiter.api.Assertions.assertTrue(evidence.contains("\"hintUsed\": true"));
        org.junit.jupiter.api.Assertions.assertTrue(evidence.contains("\"inputModality\": \"touch\""));
    }

    @Test
    void rejectsInvalidRendererIndependentAttemptEvidence() throws Exception {
        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guestJwt("learner-invalid-evidence"))
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID(), "option-hello")
                                .replace("\"inputModality\": \"touch\"", "\"inputModality\": \"telepathy\"")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ATTEMPT_EVIDENCE_INVALID"));
    }

    @Test
    void rejectsIdempotencyKeyReusedWithDifferentPayload() throws Exception {
        UUID idempotencyKey = UUID.randomUUID();
        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guestJwt("learner-conflict"))
                        .header("X-Correlation-ID", "idempotency-conflict-test")
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID(), "option-goodbye")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.correct").value(false));

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guestJwt("learner-conflict"))
                        .header("X-Correlation-ID", "idempotency-conflict-test")
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID(), "option-hello")))
                .andExpect(status().isConflict())
                .andExpect(header().string("X-Correlation-ID", "idempotency-conflict-test"))
                .andExpect(jsonPath("$.code").value("IDEMPOTENCY_CONFLICT"))
                .andExpect(jsonPath("$.traceId").value("idempotency-conflict-test"));
    }

    @Test
    void reconnectsOfflineWithoutDuplicateAndPullsMasteryReviewAndProgress() throws Exception {
        String subject = "learner-offline-" + UUID.randomUUID();
        UUID mutationId = UUID.randomUUID();
        UUID idempotencyKey = UUID.randomUUID();
        UUID attemptId = UUID.randomUUID();
        String push = syncPushJson(
                UUID.randomUUID(),
                mutationId,
                idempotencyKey,
                attemptId,
                "option-hello");

        String first = mockMvc.perform(post("/api/mobile/v1/sync/push")
                        .with(guestJwt(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(push))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rebased").value(false))
                .andExpect(jsonPath("$.results[0].status").value("applied"))
                .andExpect(jsonPath("$.results[0].result.correct").value(true))
                .andExpect(jsonPath("$.results[0].result.scoring.modelVersion").value(1))
                .andExpect(jsonPath("$.results[0].result.scoring.earnedPoints").value(1))
                .andExpect(jsonPath("$.results[0].result.progress.completed").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String cursor = toJsonField(first, "nextCursor");

        mockMvc.perform(post("/api/mobile/v1/sync/push")
                        .with(guestJwt(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(push))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("replayed"))
                .andExpect(jsonPath("$.results[0].result.attemptId")
                        .value(toNestedJsonField(first, "attemptId")));

        mockMvc.perform(get("/api/mobile/v1/mastery").with(guestJwt(subject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.modelVersion").value(1))
                .andExpect(jsonPath("$.items[0].conceptId").value("concept-basic-greetings"))
                .andExpect(jsonPath("$.items[0].score").value(1.0))
                .andExpect(jsonPath("$.items[0].evidenceCount").value(1));

        mockMvc.perform(get("/api/mobile/v1/reviews").with(guestJwt(subject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isEmpty());
        clock.advance(Duration.ofDays(1));
        mockMvc.perform(get("/api/mobile/v1/reviews").with(guestJwt(subject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].conceptId").value("concept-basic-greetings"))
                .andExpect(jsonPath("$.items[0].intervalDays").value(1));

        mockMvc.perform(get("/api/mobile/v1/sync/pull")
                        .with(guestJwt(subject))
                        .param("limit", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasMore").value(true))
                .andExpect(jsonPath("$.changes.length()").value(2));

        mockMvc.perform(get("/api/mobile/v1/sync/pull")
                        .with(guestJwt(subject))
                        .param("cursor", cursor))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.changes").isEmpty());

        long attempts = jdbc.sql("""
                        select count(*)
                        from attempts attempt
                        join identity_subjects subject
                          on subject.learner_id::text = attempt.learner_id
                        where subject.issuer = 'https://identity.test'
                          and attempt.client_attempt_id = :clientAttemptId
                        """)
                .param("clientAttemptId", attemptId)
                .query(Long.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals(1, attempts);
    }

    @Test
    void rejectsConflictingReplayAndSerializesConcurrentOfflineRetries() throws Exception {
        String subject = "learner-concurrent-" + UUID.randomUUID();
        mockMvc.perform(get("/api/mobile/v1/me/profile").with(guestJwt(subject)))
                .andExpect(status().isOk());
        UUID mutationId = UUID.randomUUID();
        UUID idempotencyKey = UUID.randomUUID();
        UUID attemptId = UUID.randomUUID();
        String push = syncPushJson(
                UUID.randomUUID(),
                mutationId,
                idempotencyKey,
                attemptId,
                "option-goodbye");
        CountDownLatch start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            Future<Integer> first = executor.submit(() -> {
                start.await();
                return mockMvc.perform(post("/api/mobile/v1/sync/push")
                                .with(guestJwt(subject))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(push))
                        .andReturn()
                        .getResponse()
                        .getStatus();
            });
            Future<Integer> second = executor.submit(() -> {
                start.await();
                return mockMvc.perform(post("/api/mobile/v1/sync/push")
                                .with(guestJwt(subject))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(push))
                        .andReturn()
                        .getResponse()
                        .getStatus();
            });
            start.countDown();
            org.junit.jupiter.api.Assertions.assertEquals(200, first.get());
            org.junit.jupiter.api.Assertions.assertEquals(200, second.get());
        }

        String conflict = syncPushJson(
                UUID.randomUUID(),
                mutationId,
                idempotencyKey,
                attemptId,
                "option-hello");
        mockMvc.perform(post("/api/mobile/v1/sync/push")
                        .with(guestJwt(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(conflict))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SYNC_MUTATION_CONFLICT"));

        long attempts = jdbc.sql("""
                        select count(*)
                        from attempts
                        where client_attempt_id = :clientAttemptId
                        """)
                .param("clientAttemptId", attemptId)
                .query(Long.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals(1, attempts);
    }

    @Test
    void keepsLearningSessionLifecycleSeparateFromAttempts() throws Exception {
        String subject = "learner-session-" + UUID.randomUUID();
        UUID clientSessionId = UUID.randomUUID();
        UUID idempotencyKey = UUID.randomUUID();
        String body = """
                {
                  "clientSessionId": "%s",
                  "courseId": "course-en-for-vi",
                  "contentVersion": 1
                }
                """.formatted(clientSessionId);
        String started = mockMvc.perform(post("/api/mobile/v1/learning-sessions")
                        .with(guestJwt(subject))
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("active"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String sessionId = toJsonField(started, "sessionId");

        mockMvc.perform(post("/api/mobile/v1/learning-sessions")
                        .with(guestJwt(subject))
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sessionId").value(sessionId));

        mockMvc.perform(post("/api/mobile/v1/learning-sessions/{sessionId}/completion", sessionId)
                        .with(guestJwt(subject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("completed"))
                .andExpect(jsonPath("$.completedAt").exists());
    }

    private String attemptJson(UUID clientAttemptId, String optionId) {
        return """
                {
                  "clientAttemptId": "%s",
                  "courseId": "course-en-for-vi",
                  "lessonId": "lesson-basic-greetings",
                  "lessonVersion": 1,
                  "exerciseId": "exercise-choose-hello",
                  "selectedOptionId": "%s",
                  "evidence": {
                    "responseTimeMs": 1200,
                    "hintUsed": true,
                    "hintLevel": 1,
                    "retryIndex": 0,
                    "confidence": 4,
                    "inputModality": "touch"
                  },
                  "occurredAt": "%s",
                  "responseTimeMs": 1200
                }
                """
                .formatted(clientAttemptId, optionId, Instant.now());
    }

    private String syncPushJson(
            UUID batchId,
            UUID mutationId,
            UUID idempotencyKey,
            UUID clientAttemptId,
            String optionId) {
        return """
                {
                  "clientBatchId": "%s",
                  "mutations": [{
                    "clientMutationId": "%s",
                    "type": "attempt.submit",
                    "idempotencyKey": "%s",
                    "payload": %s
                  }]
                }
                """
                .formatted(
                        batchId,
                        mutationId,
                        idempotencyKey,
                        attemptJson(clientAttemptId, optionId));
    }

    private RequestPostProcessor guestJwt(String subject) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", java.util.List.of("learner")))
                .authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                "ROLE_LEARNER"),
                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                "SCOPE_learning"));
    }

    private String toJsonField(String json, String field) {
        String prefix = "\"" + field + "\":\"";
        int start = json.indexOf(prefix) + prefix.length();
        return json.substring(start, json.indexOf('"', start));
    }

    private String toNestedJsonField(String json, String field) {
        return toJsonField(json, field);
    }

    @TestConfiguration
    static class ClockTestConfiguration {

        @Bean
        @Primary
        MutableClock mutableClock() {
            return new MutableClock(Instant.parse("2026-07-30T00:00:00Z"));
        }
    }

    static final class MutableClock extends Clock {

        private final AtomicReference<Instant> instant;

        MutableClock(Instant initial) {
            this.instant = new AtomicReference<>(initial);
        }

        void advance(Duration duration) {
            instant.updateAndGet(current -> current.plus(duration));
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return instant.get();
        }
    }
}

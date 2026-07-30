package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
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
                .andExpect(jsonPath("$.items[0].id").value("lesson-basic-greetings"));

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

    private String attemptJson(UUID clientAttemptId, String optionId) {
        return """
                {
                  "clientAttemptId": "%s",
                  "courseId": "course-en-for-vi",
                  "lessonId": "lesson-basic-greetings",
                  "lessonVersion": 1,
                  "exerciseId": "exercise-choose-hello",
                  "selectedOptionId": "%s",
                  "occurredAt": "%s",
                  "responseTimeMs": 1200
                }
                """
                .formatted(clientAttemptId, optionId, Instant.now());
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
}

package com.esquilospeak;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.esquilospeak.productquality.ProductQualityService;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
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
    "esquilospeak.analytics.retention-enabled=false"
})
@AutoConfigureMockMvc
class ProductQualityApiIntegrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer(DockerImageName.parse("postgres:18-alpine"));

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired MockMvc mockMvc;
    @Autowired JdbcClient jdbc;
    @Autowired ProductQualityService service;

    @Test
    void enforcesConsentAllowlistDeduplicationAndRetention() throws Exception {
        RequestPostProcessor learner = learner("quality-consent-" + UUID.randomUUID());
        UUID eventId = UUID.randomUUID();
        String event = analyticsBody(eventId, "lesson_started", "{\"result\":\"shown\"}");

        mockMvc.perform(post("/api/mobile/v1/analytics/events")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ANALYTICS_CONSENT_REQUIRED"));

        grantConsent(learner, true);
        mockMvc.perform(post("/api/mobile/v1/analytics/events")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(1))
                .andExpect(jsonPath("$.retentionDays").value(30));
        mockMvc.perform(post("/api/mobile/v1/analytics/events")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(0))
                .andExpect(jsonPath("$.duplicates").value(1));

        mockMvc.perform(post("/api/mobile/v1/analytics/events")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(analyticsBody(UUID.randomUUID(), "lesson_started", "{\"rawAnswer\":\"secret\"}")))
                .andExpect(status().is(422))
                .andExpect(jsonPath("$.code").value("ANALYTICS_EVENT_INVALID"));

        jdbc.sql("update analytics_events set expires_at = :expired where client_event_id = :eventId")
                .param("expired", Timestamp.from(Instant.now().minusSeconds(1)))
                .param("eventId", eventId)
                .update();
        org.junit.jupiter.api.Assertions.assertEquals(1, service.purgeExpired());
        grantConsent(learner, false);
        mockMvc.perform(post("/api/mobile/v1/analytics/events")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(analyticsBody(UUID.randomUUID(), "lesson_started", "{}")))
                .andExpect(status().isForbidden());
    }

    @Test
    void exposesTraceableDashboardQueueAndVersionedRecommendation() throws Exception {
        RequestPostProcessor learner = learner("quality-dashboard-" + UUID.randomUUID());
        mockMvc.perform(get("/api/mobile/v1/recommendations/next")
                        .with(learner)
                        .param("courseId", "course-en-for-vi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.policyVersion").value(1))
                .andExpect(jsonPath("$.kind").value("start_learning"))
                .andExpect(jsonPath("$.explanationCode").value("NO_LEARNING_EVIDENCE"))
                .andExpect(jsonPath("$.usedFallback").value(true));

        for (int index = 0; index < 5; index++) {
            mockMvc.perform(post("/api/mobile/v1/attempts")
                            .with(learner)
                            .header("Idempotency-Key", UUID.randomUUID())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "clientAttemptId":"%s",
                                      "courseId":"course-en-for-vi",
                                      "lessonId":"lesson-basic-greetings",
                                      "lessonVersion":1,
                                      "exerciseId":"exercise-choose-hello",
                                      "selectedOptionId":"option-goodbye",
                                      "evidence":{"retryIndex":1,"hintUsed":true},
                                      "occurredAt":"%s",
                                      "responseTimeMs":1200
                                    }
                                    """.formatted(UUID.randomUUID(), Instant.now())))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.correct").value(false));
        }
        mockMvc.perform(get("/api/mobile/v1/recommendations/next")
                        .with(learner)
                        .param("courseId", "course-en-for-vi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kind").value("review_due"))
                .andExpect(jsonPath("$.conceptId").value("concept-basic-greetings"))
                .andExpect(jsonPath("$.explanationCode").value("REVIEW_DUE_FIRST"));
        grantConsent(learner, true);
        for (int index = 0; index < 5; index++) {
            mockMvc.perform(post("/api/mobile/v1/analytics/events")
                            .with(learner)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(analyticsBody(
                                    UUID.randomUUID(),
                                    "feedback_helpfulness_recorded",
                                    "{\"feedbackHelpful\":false}")))
                    .andExpect(status().isOk());
        }

        mockMvc.perform(post("/api/mobile/v1/support/tickets")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type":"content_report",
                                  "contentRef":"lesson-basic-greetings:exercise-choose-hello",
                                  "locale":"vi",
                                  "description":"Cần kiểm tra lại distractor."
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/operations/v1/content-quality/queue")
                        .with(operations())
                        .param("courseId", "course-en-for-vi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].sourceType").value(hasItem("content_report")))
                .andExpect(jsonPath("$[*].sourceType").value(hasItem("difficulty_anomaly")))
                .andExpect(jsonPath("$[*].sourceType").value(hasItem("feedback_usefulness")))
                .andExpect(jsonPath("$[*].lessonId").value(hasItem("lesson-basic-greetings")))
                .andExpect(jsonPath("$[*].exerciseId").value(hasItem("exercise-choose-hello")));

        LocalDate today = LocalDate.now();
        mockMvc.perform(get("/api/operations/v1/product-quality/dashboard")
                        .with(operations())
                        .param("courseId", "course-en-for-vi")
                        .param("from", today.minusDays(7).toString())
                        .param("to", today.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.schemaVersion").value("product-quality-dashboard-v1"))
                .andExpect(jsonPath("$.metrics[0].code").value("first_lesson_completion"))
                .andExpect(jsonPath("$.metrics[0].numerator").value(0))
                .andExpect(jsonPath("$.metrics[0].denominator").value(1))
                .andExpect(jsonPath("$.metrics[1].code").value("unit_one_completion"))
                .andExpect(jsonPath("$.metrics[1].denominator").value(1))
                .andExpect(jsonPath("$.metrics[3].code").value("d1_retention"))
                .andExpect(jsonPath("$.metrics[3].sampleSize").value(0))
                .andExpect(jsonPath("$.samplingNote").isNotEmpty());
    }

    private void grantConsent(RequestPostProcessor learner, boolean granted) throws Exception {
        mockMvc.perform(put("/api/mobile/v1/me/consents/operational_telemetry")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"policyVersion":"telemetry-p0-v1","granted":%s}
                                """.formatted(granted)))
                .andExpect(status().isOk());
    }

    private String analyticsBody(UUID eventId, String name, String attributes) {
        return """
                {"events":[{
                  "clientEventId":"%s",
                  "name":"%s",
                  "eventVersion":1,
                  "occurredAt":"%s",
                  "courseId":"course-en-for-vi",
                  "lessonId":"lesson-basic-greetings",
                  "lessonVersion":1,
                  "attributes":%s
                }]}
                """.formatted(eventId, name, Instant.now(), attributes);
    }

    private RequestPostProcessor learner(String subject) {
        return jwt()
                .jwt(token -> token.issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", List.of("learner")))
                .authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_LEARNER"),
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("SCOPE_learning"));
    }

    private RequestPostProcessor operations() {
        return jwt().authorities(
                new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_SUPPORT"),
                new org.springframework.security.core.authority.SimpleGrantedAuthority("SCOPE_operations"));
    }
}

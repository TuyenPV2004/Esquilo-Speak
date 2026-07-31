package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false"
})
@AutoConfigureMockMvc
class AssessmentEngagementApiIntegrationTest {

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

    @Test
    void scoresA1PlacementAndIssuesNonAccreditedRecord() throws Exception {
        RequestPostProcessor learner = learner("assessment-" + UUID.randomUUID());
        mockMvc.perform(get("/api/mobile/v1/assessments/placement").with(learner))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.level").value("A1"))
                .andExpect(jsonPath("$.questions.length()").value(4));
        mockMvc.perform(post("/api/mobile/v1/assessments/placement/attempts")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "clientAttemptId": "%s",
                                  "answers": ["hello", "name", "three", "goodbye"]
                                }
                                """.formatted(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.score").value(100))
                .andExpect(jsonPath("$.passed").value(true))
                .andExpect(jsonPath("$.completionRecord.type")
                        .value("non_accredited_completion"));
    }

    @Test
    void recordsActivityIdempotentlyAndUpdatesReminderPreference() throws Exception {
        RequestPostProcessor learner = learner("engagement-" + UUID.randomUUID());
        UUID eventId = UUID.randomUUID();
        String event = """
                {"clientEventId":"%s","eventType":"lesson_completed","xpAwarded":25}
                """.formatted(eventId);
        mockMvc.perform(post("/api/mobile/v1/engagement/activities")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currentStreak").value(1))
                .andExpect(jsonPath("$.xp").value(25))
                .andExpect(jsonPath("$.achievements[0].code").value("first-step"));
        mockMvc.perform(post("/api/mobile/v1/engagement/activities")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.xp").value(25));
        mockMvc.perform(put("/api/mobile/v1/engagement/notification-preference")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"enabled":true,"reminderTime":"19:30:00","locale":"vi"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(true));
    }

    private RequestPostProcessor learner(String subject) {
        return jwt()
                .jwt(token -> token.issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", java.util.List.of("learner")))
                .authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_LEARNER"),
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("SCOPE_learning"));
    }
}

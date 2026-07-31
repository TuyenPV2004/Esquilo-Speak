package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.esquilospeak.identityprofile.PrivacyRequestService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false"
})
@AutoConfigureMockMvc
class IdentityProfileApiIntegrationTest {

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
    PrivacyRequestService privacyRequestService;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    ObjectMapper objectMapper;

    @Test
    void createsGuestProfileAndRecordsVersionedConsent() throws Exception {
        RequestPostProcessor guest = identityJwt("guest-profile", "guest");

        mockMvc.perform(get("/api/mobile/v1/me/profile").with(guest))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.actorType").value("guest"))
                .andExpect(jsonPath("$.uiLocale").value("vi"))
                .andExpect(jsonPath("$.sourceLanguage").value("vi"))
                .andExpect(jsonPath("$.targetLanguage").value("en"))
                .andExpect(jsonPath("$.ageBand").doesNotExist());

        mockMvc.perform(put("/api/mobile/v1/me/profile")
                        .with(guest)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(profileJson("under_16")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ageBand").value("under_16"));

        mockMvc.perform(put("/api/mobile/v1/me/consents/operational_telemetry")
                        .with(guest)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "policyVersion": "telemetry-p0-v1",
                                  "granted": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.purpose").value("operational_telemetry"))
                .andExpect(jsonPath("$.granted").value(true));

        mockMvc.perform(get("/api/mobile/v1/me/consents").with(guest))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2));
    }

    @Test
    void protectedProfileRejectsMissingScopeOrLearnerRole() throws Exception {
        mockMvc.perform(get("/api/mobile/v1/me/profile")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.test")
                                        .subject("missing-scope")
                                        .claim("actor_type", "guest")
                                        .claim("roles", List.of("learner")))
                                .authorities(
                                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                                "ROLE_LEARNER"))))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/mobile/v1/me/profile")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.test")
                                        .subject("missing-role")
                                        .claim("actor_type", "guest")
                                        .claim("scope", "learning"))
                                .authorities(
                                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                                "SCOPE_learning"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void requiresAccountOnboardingAndRejectsUnder16WithoutGuardianConsent()
            throws Exception {
        RequestPostProcessor account = identityJwt("account-onboarding", "account");

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(account)
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isPreconditionRequired())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));

        mockMvc.perform(put("/api/mobile/v1/me/profile")
                        .with(account)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(profileJson("under_16")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("GUARDIAN_CONSENT_REQUIRED"));

        mockMvc.perform(put("/api/mobile/v1/me/profile")
                        .with(account)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(profileJson("adult")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ageBand").value("adult"));

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(account)
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isOk());
    }

    @Test
    void mergesGuestProgressExactlyOnceAndRevokesGuestIdentity() throws Exception {
        RequestPostProcessor guest = identityJwt("guest-to-merge", "guest");
        RequestPostProcessor account = identityJwt("account-merge-target", "account");

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guest)
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isOk());

        String ticketResponse = mockMvc.perform(post("/api/mobile/v1/me/guest-merge-tickets")
                        .with(guest))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String mergeTicket = objectMapper.readTree(ticketResponse)
                .get("mergeTicket")
                .asString();

        mockMvc.perform(put("/api/mobile/v1/me/profile")
                        .with(account)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(profileJson("adult")))
                .andExpect(status().isOk());

        UUID idempotencyKey = UUID.randomUUID();
        String mergeBody = objectMapper.writeValueAsString(java.util.Map.of("mergeTicket", mergeTicket));
        String firstMerge = mockMvc.perform(post("/api/mobile/v1/me/guest-merges")
                        .with(account)
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mergeBody))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        mockMvc.perform(post("/api/mobile/v1/me/guest-merges")
                        .with(account)
                        .header("Idempotency-Key", idempotencyKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(mergeBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.guestLearnerId")
                        .value(objectMapper.readTree(firstMerge).get("guestLearnerId").asString()));

        mockMvc.perform(get("/api/mobile/v1/progress/courses/course-en-for-vi")
                        .with(account))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completedExerciseCount").value(1));

        mockMvc.perform(get("/api/mobile/v1/me/profile").with(guest))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("LEARNER_NOT_ACTIVE"));
    }

    @Test
    void exportsOwnedIdentityAndLearningDataAndRejectsCrossLearnerRead()
            throws Exception {
        RequestPostProcessor owner = identityJwt("export-owner", "guest");
        RequestPostProcessor other = identityJwt("export-other", "guest");

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(owner)
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isOk());

        String response = mockMvc.perform(post("/api/mobile/v1/me/privacy/exports")
                        .with(owner)
                        .header("Idempotency-Key", UUID.randomUUID()))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.state").value("requested"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        UUID requestId = UUID.fromString(
                objectMapper.readTree(response).get("requestId").asString());

        while (privacyRequestService.processNext()) {
            // Drain deterministic test work without waiting for the scheduler.
        }

        mockMvc.perform(get("/api/mobile/v1/me/privacy/requests/{requestId}", requestId)
                        .with(owner))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("completed"))
                .andExpect(jsonPath("$.artifact.identityProfile.profile.sourceLanguage")
                        .value("vi"))
                .andExpect(jsonPath("$.artifact.learning.attempts.length()").value(1));

        mockMvc.perform(get("/api/mobile/v1/me/privacy/requests/{requestId}", requestId)
                        .with(other))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("PRIVACY_REQUEST_NOT_FOUND"));
    }

    @Test
    void deletionRevokesAccessAndRemovesLearningData() throws Exception {
        RequestPostProcessor guest = identityJwt("delete-guest", "guest");

        String profile = mockMvc.perform(get("/api/mobile/v1/me/profile").with(guest))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        UUID learnerId =
                UUID.fromString(objectMapper.readTree(profile).get("learnerId").asString());

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(guest)
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(attemptJson(UUID.randomUUID())))
                .andExpect(status().isOk());

        String deletionResponse = mockMvc.perform(post("/api/mobile/v1/me/privacy/deletions")
                        .with(guest)
                        .header("Idempotency-Key", UUID.randomUUID()))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.state").value("requested"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        UUID deletionRequestId = UUID.fromString(
                objectMapper.readTree(deletionResponse).get("requestId").asString());

        mockMvc.perform(get("/api/mobile/v1/me/profile").with(guest))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("LEARNER_NOT_ACTIVE"));

        mockMvc.perform(get(
                                "/api/mobile/v1/me/privacy/requests/{requestId}",
                                deletionRequestId)
                        .with(guest))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("requested"));

        while (privacyRequestService.processNext()) {
            // Drain deterministic test work without waiting for the scheduler.
        }

        String state = jdbc.sql("select state from learners where id = :learnerId")
                .param("learnerId", learnerId)
                .query(String.class)
                .single();
        int attempts = jdbc.sql("select count(*) from attempts where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .query(Integer.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals("deleted", state);
        org.junit.jupiter.api.Assertions.assertEquals(0, attempts);
    }

    @Test
    void schedulesInactiveGuestDeletionAfterNinetyDays() throws Exception {
        RequestPostProcessor guest = identityJwt("inactive-guest", "guest");
        String profile = mockMvc.perform(get("/api/mobile/v1/me/profile").with(guest))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        UUID learnerId =
                UUID.fromString(objectMapper.readTree(profile).get("learnerId").asString());
        jdbc.sql("update learners set last_activity_at = :lastActivity where id = :learnerId")
                .param("lastActivity", java.sql.Timestamp.from(
                        Instant.now().minus(91, ChronoUnit.DAYS)))
                .param("learnerId", learnerId)
                .update();

        org.junit.jupiter.api.Assertions.assertTrue(
                privacyRequestService.requestNextInactiveGuestDeletion());
        while (privacyRequestService.processNext()) {
            // Drain deterministic test work without waiting for the scheduler.
        }

        String state = jdbc.sql("select state from learners where id = :learnerId")
                .param("learnerId", learnerId)
                .query(String.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals("deleted", state);
    }

    private RequestPostProcessor identityJwt(String subject, String actorType) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
                        .audience(List.of("esquilospeak-mobile"))
                        .claim("actor_type", actorType)
                        .claim("scope", "learning")
                        .claim("roles", List.of("learner")))
                .authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                "ROLE_LEARNER"),
                        new org.springframework.security.core.authority.SimpleGrantedAuthority(
                                "SCOPE_learning"));
    }

    private String profileJson(String ageBand) {
        return """
                {
                  "uiLocale": "vi",
                  "sourceLanguage": "vi",
                  "targetLanguage": "en",
                  "ageBand": "%s",
                  "learningGoal": "daily_communication",
                  "preferences": {"quietMode": true}
                }
                """
                .formatted(ageBand);
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
                  "responseTimeMs": 1200
                }
                """
                .formatted(clientAttemptId, Instant.now());
    }
}

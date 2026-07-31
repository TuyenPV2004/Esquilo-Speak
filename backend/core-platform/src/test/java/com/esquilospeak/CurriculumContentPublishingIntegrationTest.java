package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.esquilospeak.curriculumcontent.CurriculumContentAdminService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
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
import tools.jackson.databind.ObjectMapper;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.content.publisher-enabled=false",
    "esquilospeak.privacy.processor-enabled=false"
})
@AutoConfigureMockMvc
class CurriculumContentPublishingIntegrationTest {

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
    CurriculumContentAdminService contentAdminService;

    @Autowired
    ObjectMapper objectMapper;

    @Test
    void exposesPublishedAdvancedActivityDefinitionsWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/api/mobile/v1/courses/{courseId}/advanced-activities",
                        "course-en-for-vi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value("activity-basic-greetings"))
                .andExpect(jsonPath("$.items[0].targetLocale").value("en"));
    }

    @Test
    void rejectsLearnerRoleAndBrokenAuthoringReferences() throws Exception {
        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                "course-p0-validation", 1)
                        .with(learnerJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseDraft("missing-option", false)))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                "course-p0-validation", 1)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseDraft("missing-option", false)))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.code").value("CONTENT_INVALID"));
    }

    @Test
    void publishesVersionedContentWithoutAnswerLeakageAndRollsBack() throws Exception {
        String courseId = "course-versioned-p0";
        int version = 2;
        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseDraft(null, true)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.version").value(version));

        mockMvc.perform(get("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.lessons[0].exercises[0].correctAnswer")
                        .value(true))
                .andExpect(jsonPath("$.content.lessons[0].exercises[0].explanation.vi")
                        .exists());

        transition(courseId, version, "review", null);
        transition(courseId, version, "approved", null);
        transition(
                courseId,
                version,
                "scheduled",
                Instant.now().plus(1, ChronoUnit.HOURS));

        mockMvc.perform(get("/api/mobile/v1/courses")
                        .param("sourceLanguage", "vi")
                        .param("targetLanguage", "en"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.id == 'course-versioned-p0')]")
                        .isEmpty());

        jdbc.sql("""
                        update course_versions
                        set effective_at = now() - interval '1 second'
                        where course_id = :courseId and version = :version
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .update();
        org.junit.jupiter.api.Assertions.assertTrue(
                contentAdminService.publishNextDueVersion());

        mockMvc.perform(get("/api/mobile/v1/courses")
                        .param("sourceLanguage", "vi")
                        .param("targetLanguage", "en"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.id == 'course-versioned-p0')].version")
                        .value(version))
                .andExpect(jsonPath(
                                "$.items[?(@.id == 'course-versioned-p0')].proficiency.frameworkCode")
                        .value("cefr"))
                .andExpect(jsonPath(
                                "$.items[?(@.id == 'course-versioned-p0')].proficiency.targetLevelCode")
                        .value("A1"));

        mockMvc.perform(get("/api/mobile/v1/lessons/{lessonId}", "lesson-versioned-greetings")
                        .param("version", String.valueOf(version)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises[0].type").value("true_false"))
                .andExpect(jsonPath("$.exercises[0].options[0].id").value("true"))
                .andExpect(jsonPath("$.exercises[0].options[1].id").value("false"))
                .andExpect(jsonPath("$.exercises[0].media.objectKey")
                        .value("content/audio/greeting-v2.mp3"))
                .andExpect(jsonPath("$.exercises[0].correctAnswer").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].correctOptionId").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].explanation").doesNotExist());

        int auditEvents = jdbc.sql("""
                        select count(*) from content_audit_events
                        where course_id = :courseId
                        """)
                .param("courseId", courseId)
                .query(Integer.class)
                .single();
        org.junit.jupiter.api.Assertions.assertTrue(auditEvents >= 4);

        mockMvc.perform(post("/api/admin/v1/content/courses/{courseId}/rollbacks", courseId)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"targetVersion\":1}"))
                .andExpect(status().isNotFound());

        String seededCourse = "course-en-for-vi";
        createReplacementForSeededCourse(seededCourse);
        org.junit.jupiter.api.Assertions.assertEquals(
                "retired", contentState(seededCourse, 1));
        org.junit.jupiter.api.Assertions.assertEquals(
                "published", contentState(seededCourse, 2));
        mockMvc.perform(post("/api/admin/v1/content/courses/{courseId}/rollbacks", seededCourse)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"targetVersion\":1}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1));
        org.junit.jupiter.api.Assertions.assertEquals(
                "published", contentState(seededCourse, 1));
        org.junit.jupiter.api.Assertions.assertEquals(
                "retired", contentState(seededCourse, 2));

        mockMvc.perform(post("/api/mobile/v1/attempts")
                        .with(learnerJwt())
                        .header("Idempotency-Key", UUID.randomUUID())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "clientAttemptId": "%s",
                                  "courseId": "course-en-for-vi",
                                  "lessonId": "lesson-seeded-v2",
                                  "lessonVersion": 2,
                                  "exerciseId": "exercise-greeting-true-false",
                                  "selectedOptionId": "true",
                                  "occurredAt": "%s"
                                }
                                """.formatted(UUID.randomUUID(), Instant.now())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.correct").value(true))
                .andExpect(jsonPath("$.feedback.explanation.vi").exists());
    }

    private String contentState(String courseId, int version) {
        return jdbc.sql("""
                        select state from course_versions
                        where course_id = :courseId and version = :version
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(String.class)
                .single();
    }

    private void createReplacementForSeededCourse(String courseId) throws Exception {
        int version = 2;
        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(courseDraft(null, true)
                                .replace("lesson-versioned-greetings", "lesson-seeded-v2")))
                .andExpect(status().isCreated());
        transition(courseId, version, "review", null);
        transition(courseId, version, "approved", null);
        transition(courseId, version, "published", null);
    }

    private void transition(
            String courseId, int version, String targetState, Instant effectiveAt)
            throws Exception {
        String body = objectMapper.writeValueAsString(java.util.Map.of(
                "targetState",
                targetState,
                "effectiveAt",
                effectiveAt == null ? "" : effectiveAt.toString()));
        if (effectiveAt == null) {
            body = "{\"targetState\":\"" + targetState + "\"}";
        }
        mockMvc.perform(post(
                                "/api/admin/v1/content/courses/{courseId}/versions/{version}/transitions",
                                courseId,
                                version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());
    }

    private RequestPostProcessor contentStaffJwt() {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject("content-author")
                        .claim("scope", "content")
                        .claim("roles", java.util.List.of("content_staff")))
                .authorities(
                        new SimpleGrantedAuthority("SCOPE_content"),
                        new SimpleGrantedAuthority("ROLE_CONTENT_STAFF"));
    }

    private RequestPostProcessor learnerJwt() {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject("content-learner")
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", java.util.List.of("learner")))
                .authorities(
                        new SimpleGrantedAuthority("SCOPE_learning"),
                        new SimpleGrantedAuthority("ROLE_LEARNER"));
    }

    private String courseDraft(String correctOptionId, boolean trueFalse) {
        String exercise = trueFalse
                ? """
                  {
                    "id": "exercise-greeting-true-false",
                    "type": "true_false",
                    "prompt": {"vi": "Hello là một lời chào.", "en": "Hello is a greeting."},
                    "correctAnswer": true,
                    "explanation": {
                      "vi": "Hello là lời chào tiếng Anh thông dụng.",
                      "en": "Hello is a common English greeting."
                    },
                    "skill": "vocabulary",
                    "conceptIds": ["concept-basic-greetings"],
                    "media": {
                      "id": "media-greeting-audio",
                      "type": "audio",
                      "objectKey": "content/audio/greeting-v2.mp3",
                      "checksum": "sha256:synthetic-test-audio",
                      "locale": "en",
                      "durationMs": 1200
                    }
                  }
                  """
                : """
                  {
                    "id": "exercise-invalid-reference",
                    "type": "multiple_choice",
                    "prompt": {"vi": "Chọn lời chào.", "en": "Choose a greeting."},
                    "options": [
                      {"id": "option-hello", "text": {"vi": "Hello", "en": "Hello"}},
                      {"id": "option-goodbye", "text": {"vi": "Goodbye", "en": "Goodbye"}}
                    ],
                    "correctOptionId": "%s",
                    "explanation": {"vi": "Hello là lời chào.", "en": "Hello is a greeting."},
                    "skill": "vocabulary",
                    "conceptIds": ["concept-basic-greetings"]
                  }
                  """.formatted(correctOptionId);
        return """
                {
                  "sourceLanguage": "vi",
                  "targetLanguage": "en",
                  "locale": "vi",
                  "compatibilityVersion": 1,
                  "proficiency": {
                    "frameworkCode": "cefr",
                    "frameworkVersion": "2020",
                    "entryLevelCode": "PRE_A1",
                    "targetLevelCode": "A1"
                  },
                  "title": {"vi": "Tiếng Anh có version", "en": "Versioned English"},
                  "description": {
                    "vi": "Nội dung kiểm thử publishing.",
                    "en": "Publishing test content."
                  },
                  "owner": "EsquiloSpeak content team",
                  "license": "Proprietary",
                  "units": [{
                    "id": "unit-greetings",
                    "title": {"vi": "Lời chào", "en": "Greetings"},
                    "lessons": [{
                      "id": "lesson-versioned-greetings",
                      "locale": "vi",
                      "title": {"vi": "Lời chào có version", "en": "Versioned greetings"},
                      "objectives": [{
                        "vi": "Nhận biết lời chào.",
                        "en": "Recognize a greeting."
                      }],
                      "estimatedMinutes": 5,
                      "exercises": [%s]
                    }]
                  }]
                }
                """.formatted(exercise);
    }
}

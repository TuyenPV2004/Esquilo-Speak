package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.esquilospeak.curriculumcontent.CurriculumContentAdminService;
import com.esquilospeak.curriculumcontent.CurriculumContentService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Objects;
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
import tools.jackson.databind.JsonNode;

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
    CurriculumContentService contentService;

    @Autowired
    ObjectMapper objectMapper;

    @Test
    void publishesAndScoresEveryExerciseEngineV2Type() throws Exception {
        String courseId = "course-engine-v2-fixture";
        int version = 1;
        String draft;
        try (var stream = Objects.requireNonNull(getClass()
                .getResourceAsStream("/content/unit-one-v2-admin-draft.json"))) {
            draft = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }
        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draft))
                .andExpect(status().isCreated());
        transition(courseId, version, "review", null);
        transition(courseId, version, "approved", null);
        transition(courseId, version, "published", null);

        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-flashcard", java.util.Map.of("kind", "self_assessment", "value", "learning"));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-choice", java.util.Map.of("kind", "option", "optionId", "option-meaning"));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-listen", java.util.Map.of("kind", "option", "optionId", "option-first"));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-matching", java.util.Map.of(
                        "kind", "pairs",
                        "pairs", java.util.List.of(
                                java.util.Map.of("leftId", "left-hello", "rightId", "right-hello"),
                                java.util.Map.of("leftId", "left-goodbye", "rightId", "right-goodbye"))));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-ordering", java.util.Map.of(
                        "kind", "sequence", "itemIds", java.util.List.of("item-good", "item-morning")));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-fill", java.util.Map.of("kind", "text", "text", "  hello,   ANA! "));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-truth", java.util.Map.of("kind", "boolean", "value", true));
        org.junit.jupiter.api.Assertions.assertEquals(
                java.util.Map.of("kind", "boolean", "value", true),
                contentService.exerciseAnswer(
                                courseId,
                                "lesson-greetings",
                                version,
                                "exercise-greetings-truth",
                                java.util.Map.of("kind", "boolean", "value", true))
                        .correctResponse());
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-comprehension", java.util.Map.of("kind", "option", "optionId", "option-answer"));
        assertCorrect(courseId, "lesson-greetings", version,
                "exercise-greetings-dictation", java.util.Map.of("kind", "text", "text", "hello"));

        mockMvc.perform(get("/api/mobile/v1/lessons/{lessonId}", "lesson-greetings")
                        .param("version", String.valueOf(version)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises.length()").value(9))
                .andExpect(jsonPath("$.exercises[2].transcript.en").value("Hello"))
                .andExpect(jsonPath("$.exercises[3].correctPairs").doesNotExist())
                .andExpect(jsonPath("$.exercises[4].correctOrder").doesNotExist())
                .andExpect(jsonPath("$.exercises[5].acceptedAnswers").doesNotExist());

        mockMvc.perform(get("/api/mobile/v1/courses/{courseId}/lessons", courseId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(5))
                .andExpect(jsonPath("$.items[0].unitId").value("unit-first-contact"))
                .andExpect(jsonPath("$.items[0].unitTitle.en").value("First contact"))
                .andExpect(jsonPath("$.items[4].position").value(5));

        String learnerSubject = "unit-one-learner-" + UUID.randomUUID();
        JsonNode fixture = objectMapper.readTree(draft);
        int submitted = 0;
        for (JsonNode lesson : fixture.get("units").get(0).get("lessons")) {
            for (JsonNode exercise : lesson.get("exercises")) {
                UUID clientAttemptId = UUID.randomUUID();
                java.util.Map<String, Object> request = new java.util.LinkedHashMap<>();
                request.put("clientAttemptId", clientAttemptId.toString());
                request.put("courseId", courseId);
                request.put("lessonId", lesson.get("id").asString());
                request.put("lessonVersion", version);
                request.put("exerciseId", exercise.get("id").asString());
                request.put("response", correctResponse(exercise));
                request.put("occurredAt", Instant.now().plus(submitted, ChronoUnit.SECONDS).toString());
                request.put("evidence", java.util.Map.of(
                        "responseTimeMs", 1000,
                        "hintUsed", false,
                        "hintLevel", 0,
                        "retryIndex", 0,
                        "inputModality", "touch"));
                mockMvc.perform(post("/api/mobile/v1/attempts")
                                .with(learnerJwt(learnerSubject))
                                .header("Idempotency-Key", UUID.randomUUID())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request)))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.correct").value(true));
                submitted++;
            }
        }
        org.junit.jupiter.api.Assertions.assertEquals(45, submitted);
        mockMvc.perform(get("/api/mobile/v1/progress/courses/{courseId}", courseId)
                        .with(learnerJwt(learnerSubject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completedExerciseCount").value(45))
                .andExpect(jsonPath("$.totalExerciseCount").value(45))
                .andExpect(jsonPath("$.lessonProgress.length()").value(5))
                .andExpect(jsonPath("$.lessonProgress[4].status").value("completed"));
        mockMvc.perform(get("/api/mobile/v1/mastery").with(learnerJwt(learnerSubject)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(5))
                .andExpect(jsonPath("$.items[0].evidenceCount").value(9));
        Long schedules = jdbc.sql("""
                        select count(*)
                        from review_schedules schedule
                        join identity_subjects subject on subject.learner_id::text = schedule.learner_id
                        where subject.subject_hash = :subjectHash
                        """)
                .param("subjectHash", java.util.HexFormat.of().formatHex(
                        MessageDigest.getInstance("SHA-256").digest(
                                ("https://identity.test\0" + learnerSubject)
                                        .getBytes(StandardCharsets.UTF_8))))
                .query(Long.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals(5L, schedules);
    }

    private java.util.Map<String, Object> correctResponse(JsonNode exercise) {
        String type = exercise.get("type").asString();
        return switch (type) {
            case "flashcard" -> java.util.Map.of("kind", "self_assessment", "value", "learning");
            case "multiple_choice", "listen_select", "comprehension" -> java.util.Map.of(
                    "kind", "option", "optionId", exercise.get("correctOptionId").asString());
            case "true_false" -> java.util.Map.of(
                    "kind", "boolean", "value", exercise.get("correctAnswer").asBoolean());
            case "fill_blank", "dictation" -> java.util.Map.of(
                    "kind", "text", "text", exercise.get("acceptedAnswers").get(0).asString());
            case "ordering" -> java.util.Map.of(
                    "kind", "sequence", "itemIds", stringValues(exercise.get("correctOrder")));
            case "matching" -> java.util.Map.of(
                    "kind", "pairs", "pairs", pairValues(exercise.get("correctPairs")));
            default -> throw new IllegalArgumentException("Unsupported fixture type " + type);
        };
    }

    private java.util.List<String> stringValues(JsonNode values) {
        java.util.List<String> result = new java.util.ArrayList<>();
        values.forEach(value -> result.add(value.asString()));
        return result;
    }

    private java.util.List<java.util.Map<String, String>> pairValues(JsonNode values) {
        java.util.List<java.util.Map<String, String>> result = new java.util.ArrayList<>();
        values.forEach(value -> result.add(java.util.Map.of(
                "leftId", value.get("leftId").asString(),
                "rightId", value.get("rightId").asString())));
        return result;
    }

    private void assertCorrect(
            String courseId,
            String lessonId,
            int version,
            String exerciseId,
            java.util.Map<String, Object> response) {
        org.junit.jupiter.api.Assertions.assertTrue(contentService.exerciseAnswer(
                courseId, lessonId, version, exerciseId, response).correct());
    }

    @Test
    void exposesPublishedAdvancedActivityDefinitionsWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/api/mobile/v1/courses/{courseId}/advanced-activities",
                        "course-en-for-vi"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value("activity-basic-greetings"))
                .andExpect(jsonPath("$.items[0].targetLocale").value("en"));
    }

    @Test
    void publishesPipelineCompiledFixtureWithoutApplicationCodeChanges() throws Exception {
        String courseId = "course-authoring-demo";
        int version = 1;
        String draft;
        try (var stream = Objects.requireNonNull(getClass()
                .getResourceAsStream("/content/authoring-demo-admin-draft.json"))) {
            draft = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }

        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draft))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.state").value("draft"));

        transition(courseId, version, "review", null);
        transition(courseId, version, "approved", null);
        transition(courseId, version, "published", null);

        mockMvc.perform(get("/api/mobile/v1/lessons/{lessonId}", "lesson-authoring-demo")
                        .param("version", String.valueOf(version)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises[0].prompt.en")
                        .value("Complete: My ___ is Ana."))
                .andExpect(jsonPath("$.exercises[0].correctOptionId").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].explanation").doesNotExist());

        mockMvc.perform(put("/api/admin/v1/content/courses/{courseId}/versions/{version}",
                                courseId, version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draft))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONTENT_VERSION_IMMUTABLE"));
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

        mockMvc.perform(post(
                                "/api/admin/v1/content/courses/{courseId}/versions/{version}/transitions",
                                courseId,
                                version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"targetState\":\"review\"}"))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.code").value("CONTENT_INVALID"));

        transition(courseId, version, "review", null);
        String reviewAudit = jdbc.sql("""
                        select details::text
                        from content_audit_events
                        where course_id = :courseId
                          and course_version = :version
                          and action = 'STATE_CHANGED'
                          and details ->> 'to' = 'review'
                        order by occurred_at desc
                        limit 1
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(String.class)
                .single();
        org.junit.jupiter.api.Assertions.assertTrue(reviewAudit.contains("content-review-v1"));
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
        java.util.Map<String, Object> transition = new java.util.LinkedHashMap<>();
        transition.put("targetState", targetState);
        if (effectiveAt != null) {
            transition.put("effectiveAt", effectiveAt.toString());
        }
        if ("review".equals(targetState)) {
            transition.put("reviewEvidence", reviewEvidence());
        }
        String body = objectMapper.writeValueAsString(transition);
        mockMvc.perform(post(
                                "/api/admin/v1/content/courses/{courseId}/versions/{version}/transitions",
                                courseId,
                                version)
                        .with(contentStaffJwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());
    }

    private java.util.Map<String, Object> reviewEvidence() {
        return java.util.Map.of(
                "checklistVersion",
                "content-review-v1",
                "checks",
                java.util.List.of(
                        reviewCheck("schema"),
                        reviewCheck("references"),
                        reviewCheck("pedagogy"),
                        reviewCheck("language"),
                        reviewCheck("media-accessibility"),
                        reviewCheck("answer-integrity"),
                        reviewCheck("preview")));
    }

    private java.util.Map<String, Object> reviewCheck(String id) {
        return java.util.Map.of(
                "id", id,
                "passed", true,
                "evidence", "integration-test:" + id);
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
        return learnerJwt("content-learner");
    }

    private RequestPostProcessor learnerJwt(String subject) {
        return jwt()
                .jwt(token -> token
                        .issuer("https://identity.test")
                        .subject(subject)
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

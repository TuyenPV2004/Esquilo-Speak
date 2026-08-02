package com.esquilospeak.learning;

import com.esquilospeak.ApiException;
import com.esquilospeak.curriculumcontent.CurriculumContentService;
import com.esquilospeak.curriculumcontent.CurriculumContentService.ExerciseAnswer;
import com.esquilospeak.curriculumcontent.CurriculumContentService.LessonStructure;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Types;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.Clock;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

@Service
public class LearningService {

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final CurriculumContentService contentService;
    private final ApplicationEventPublisher events;
    private final Clock clock;
    private final LearningSyncCursorProvider syncCursorProvider;

    public LearningService(
            JdbcClient jdbc,
            ObjectMapper objectMapper,
            CurriculumContentService contentService,
            ApplicationEventPublisher events,
            Clock clock,
            LearningSyncCursorProvider syncCursorProvider) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.contentService = contentService;
        this.events = events;
        this.clock = clock;
        this.syncCursorProvider = syncCursorProvider;
    }

    @Transactional
    public AttemptResult submit(
            String learnerId, UUID idempotencyKey, AttemptRequest request) {
        String requestHash = hash(request);
        StoredAttempt existing = findExisting(learnerId, idempotencyKey, request.clientAttemptId());
        if (existing != null) {
            ensureSameRequest(existing, requestHash);
            return resultFor(learnerId, existing);
        }
        validateSession(learnerId, request);

        ExerciseAnswer answer = contentService.exerciseAnswer(
                request.courseId(),
                request.lessonId(),
                request.lessonVersion(),
                request.exerciseId(),
                request.response());
        StoredAttempt created = new StoredAttempt(
                UUID.randomUUID(),
                request.clientAttemptId(),
                idempotencyKey,
                requestHash,
                request.courseId(),
                request.lessonId(),
                request.lessonVersion(),
                request.exerciseId(),
                request.selectedOptionId(),
                request.response(),
                answer.correct(),
                clock.instant());
        try {
            jdbc.sql("""
                            insert into attempts (
                                id, learner_id, client_attempt_id, idempotency_key, request_hash,
                                course_id, lesson_id, lesson_version, exercise_id,
                                selected_option_id, response, evidence, correct, occurred_at, accepted_at, response_time_ms,
                                session_id
                            ) values (
                                :id, :learnerId, :clientAttemptId, :idempotencyKey, :requestHash,
                                :courseId, :lessonId, :lessonVersion, :exerciseId,
                                :selectedOptionId, cast(:response as jsonb), cast(:evidence as jsonb), :correct, :occurredAt, :acceptedAt, :responseTimeMs,
                                :sessionId
                            )
                            """)
                    .param("id", created.id())
                    .param("learnerId", learnerId)
                    .param("clientAttemptId", created.clientAttemptId())
                    .param("idempotencyKey", created.idempotencyKey())
                    .param("requestHash", created.requestHash())
                    .param("courseId", created.courseId())
                    .param("lessonId", created.lessonId())
                    .param("lessonVersion", created.lessonVersion())
                    .param("exerciseId", created.exerciseId())
                    .param("selectedOptionId", created.selectedOptionId(), Types.VARCHAR)
                    .param("response", writeJson(created.response()))
                    .param("evidence", writeJson(request.evidence()))
                    .param("correct", created.correct())
                    .param("occurredAt", Timestamp.from(request.occurredAt()))
                    .param("acceptedAt", Timestamp.from(created.acceptedAt()))
                    .param("responseTimeMs", request.responseTimeMs())
                    .param("sessionId", request.sessionId(), Types.OTHER)
                    .update();
        } catch (DuplicateKeyException exception) {
            StoredAttempt raced = findExisting(learnerId, idempotencyKey, request.clientAttemptId());
            if (raced == null) {
                throw exception;
            }
            ensureSameRequest(raced, requestHash);
            return resultFor(learnerId, raced);
        }
        events.publishEvent(new AttemptAccepted(
                created.id(),
                learnerId,
                created.clientAttemptId(),
                created.courseId(),
                created.lessonId(),
                created.lessonVersion(),
                created.exerciseId(),
                answer.conceptIds(),
                created.correct(),
                created.acceptedAt()));
        return resultFor(learnerId, created);
    }

    public CourseProgress progress(String learnerId, String courseId) {
        List<LessonStructure> lessons = contentService.courseStructure(courseId);
        Map<String, Integer> completedByLesson = new HashMap<>();
        jdbc.sql("""
                        select lesson_id, lesson_version,
                               count(distinct exercise_id) as completed
                        from attempts
                        where learner_id = :learnerId
                          and course_id = :courseId
                          and correct = true
                          and evidence ->> 'practiceMode' is null
                        group by lesson_id, lesson_version
                        """)
                .param("learnerId", learnerId)
                .param("courseId", courseId)
                .query((rs, rowNum) -> Map.entry(
                        rs.getString("lesson_id") + ":" + rs.getInt("lesson_version"),
                        rs.getInt("completed")))
                .list()
                .forEach(entry -> completedByLesson.put(entry.getKey(), entry.getValue()));

        Instant lastActivity = jdbc.sql("""
                        select max(accepted_at)
                        from attempts
                        where learner_id = :learnerId and course_id = :courseId
                        """)
                .param("learnerId", learnerId)
                .param("courseId", courseId)
                .query((rs, rowNum) -> {
                    Timestamp timestamp = rs.getTimestamp(1);
                    return timestamp == null ? null : timestamp.toInstant();
                })
                .optional()
                .orElse(Instant.EPOCH);

        List<LessonProgress> lessonProgress = lessons.stream()
                .map(lesson -> {
                    int completed = Math.min(
                            completedByLesson.getOrDefault(
                                    lesson.lessonId() + ":" + lesson.lessonVersion(), 0),
                            lesson.exerciseCount());
                    String status = completed == 0
                            ? "not_started"
                            : completed == lesson.exerciseCount() ? "completed" : "in_progress";
                    return new LessonProgress(
                            lesson.lessonId(),
                            lesson.lessonVersion(),
                            status,
                            completed,
                            lesson.exerciseCount());
                })
                .toList();
        int completed = lessonProgress.stream().mapToInt(LessonProgress::completedExerciseCount).sum();
        int total = lessonProgress.stream().mapToInt(LessonProgress::totalExerciseCount).sum();
        synchronizeCompletions(learnerId, courseId, lessonProgress);
        int completedLessons = (int) lessonProgress.stream()
                .filter(lesson -> "completed".equals(lesson.status()))
                .count();
        return new CourseProgress(
                courseId,
                completed,
                total,
                lastActivity,
                lessonProgress,
                completedLessons,
                lessonProgress.size(),
                !lessonProgress.isEmpty() && completedLessons == lessonProgress.size());
    }

    private void validateSession(String learnerId, AttemptRequest request) {
        if (request.sessionId() == null) {
            return;
        }
        boolean valid = jdbc.sql("""
                        select exists(
                            select 1
                            from learning_sessions
                            where id = :sessionId
                              and learner_id = :learnerId
                              and course_id = :courseId
                              and content_version = :contentVersion
                        )
                        """)
                .param("sessionId", request.sessionId())
                .param("learnerId", learnerId)
                .param("courseId", request.courseId())
                .param("contentVersion", request.lessonVersion())
                .query(Boolean.class)
                .single();
        if (!valid) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "LEARNING_SESSION_INVALID",
                    "The attempt does not belong to the supplied learning session.");
        }
    }

    private void synchronizeCompletions(
            String learnerId, String courseId, List<LessonProgress> lessons) {
        Instant changedAt = clock.instant();
        Set<String> currentLessonIds = new HashSet<>();
        for (LessonProgress lesson : lessons) {
            currentLessonIds.add(lesson.lessonId());
            boolean completed = "completed".equals(lesson.status());
            Boolean previous = jdbc.sql("""
                            select active
                            from learning_completions
                            where learner_id = :learnerId
                              and course_id = :courseId
                              and lesson_id = :lessonId
                            """)
                    .param("learnerId", learnerId)
                    .param("courseId", courseId)
                    .param("lessonId", lesson.lessonId())
                    .query(Boolean.class)
                    .optional()
                    .orElse(null);
            if (previous != null && previous == completed) {
                continue;
            }
            jdbc.sql("""
                            insert into learning_completions (
                                learner_id, course_id, lesson_id, lesson_version,
                                active, completed_at, updated_at
                            ) values (
                                :learnerId, :courseId, :lessonId, :lessonVersion,
                                :active, :completedAt, :updatedAt
                            )
                            on conflict (learner_id, course_id, lesson_id) do update
                            set lesson_version = excluded.lesson_version,
                                active = excluded.active,
                                completed_at = excluded.completed_at,
                                updated_at = excluded.updated_at
                            """)
                    .param("learnerId", learnerId)
                    .param("courseId", courseId)
                    .param("lessonId", lesson.lessonId())
                    .param("lessonVersion", lesson.lessonVersion())
                    .param("active", completed)
                    .param(
                            "completedAt",
                            completed ? Timestamp.from(changedAt) : null,
                            Types.TIMESTAMP)
                    .param("updatedAt", Timestamp.from(changedAt))
                    .update();
            events.publishEvent(new CompletionChanged(
                    learnerId,
                    courseId,
                    lesson.lessonId(),
                    lesson.lessonVersion(),
                    completed,
                    changedAt));
        }
        List<LessonCompletion> removedLessons = jdbc.sql("""
                        select lesson_id, lesson_version
                        from learning_completions
                        where learner_id = :learnerId
                          and course_id = :courseId
                          and active = true
                        """)
                .param("learnerId", learnerId)
                .param("courseId", courseId)
                .query((rs, rowNum) -> new LessonCompletion(
                        rs.getString("lesson_id"), rs.getInt("lesson_version")))
                .list()
                .stream()
                .filter(completion -> !currentLessonIds.contains(completion.lessonId()))
                .toList();
        for (LessonCompletion removed : removedLessons) {
            jdbc.sql("""
                            update learning_completions
                            set active = false, completed_at = null, updated_at = :updatedAt
                            where learner_id = :learnerId
                              and course_id = :courseId
                              and lesson_id = :lessonId
                            """)
                    .param("updatedAt", Timestamp.from(changedAt))
                    .param("learnerId", learnerId)
                    .param("courseId", courseId)
                    .param("lessonId", removed.lessonId())
                    .update();
            events.publishEvent(new CompletionChanged(
                    learnerId,
                    courseId,
                    removed.lessonId(),
                    removed.lessonVersion(),
                    false,
                    changedAt));
        }
    }

    private AttemptResult resultFor(String learnerId, StoredAttempt attempt) {
        ExerciseAnswer answer = contentService.exerciseAnswer(
                attempt.courseId(),
                attempt.lessonId(),
                attempt.lessonVersion(),
                attempt.exerciseId(),
                attempt.response());
        Feedback feedback = new Feedback(
                attempt.correct() ? "answer.correct" : "answer.incorrect",
                answer.correctOptionId(),
                answer.correctResponse(),
                answer.explanation());
        return new AttemptResult(
                attempt.id(),
                attempt.clientAttemptId(),
                attempt.acceptedAt(),
                attempt.correct(),
                new Scoring(1, attempt.correct() ? 1 : 0, 1),
                feedback,
                progress(learnerId, attempt.courseId()),
                syncCursorProvider.currentCursor(learnerId));
    }

    private StoredAttempt findExisting(String learnerId, UUID idempotencyKey, UUID clientAttemptId) {
        return jdbc.sql("""
                        select id, client_attempt_id, idempotency_key, request_hash, course_id,
                               lesson_id, lesson_version, exercise_id, selected_option_id, response::text,
                               correct, accepted_at
                        from attempts
                        where learner_id = :learnerId
                          and (idempotency_key = :idempotencyKey or client_attempt_id = :clientAttemptId)
                        limit 1
                        """)
                .param("learnerId", learnerId)
                .param("idempotencyKey", idempotencyKey)
                .param("clientAttemptId", clientAttemptId)
                .query((rs, rowNum) -> new StoredAttempt(
                        rs.getObject("id", UUID.class),
                        rs.getObject("client_attempt_id", UUID.class),
                        rs.getObject("idempotency_key", UUID.class),
                        rs.getString("request_hash"),
                        rs.getString("course_id"),
                        rs.getString("lesson_id"),
                        rs.getInt("lesson_version"),
                        rs.getString("exercise_id"),
                        rs.getString("selected_option_id"),
                        readMap(rs.getString("response")),
                        rs.getBoolean("correct"),
                        rs.getTimestamp("accepted_at").toInstant()))
                .optional()
                .orElse(null);
    }

    private void ensureSameRequest(StoredAttempt existing, String requestHash) {
        if (!existing.requestHash().equals(requestHash)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "IDEMPOTENCY_CONFLICT",
                    "The idempotency key or client attempt ID was reused with a different request.");
        }
    }

    private String hash(AttemptRequest request) {
        try {
            byte[] payload = objectMapper.writeValueAsString(request).getBytes(StandardCharsets.UTF_8);
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(payload));
        } catch (JacksonException | NoSuchAlgorithmException exception) {
            throw new IllegalStateException("Could not create an attempt request hash.", exception);
        }
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize an attempt response.", exception);
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readMap(String value) {
        try {
            return objectMapper.readValue(value, Map.class);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored attempt response is invalid.", exception);
        }
    }

    public record AttemptRequest(
            UUID clientAttemptId,
            String courseId,
            String lessonId,
            int lessonVersion,
            String exerciseId,
            String selectedOptionId,
            Map<String, Object> response,
            Map<String, Object> evidence,
            Instant occurredAt,
            Integer responseTimeMs,
            UUID sessionId) {
        public AttemptRequest {
            if (response == null && selectedOptionId != null && !selectedOptionId.isBlank()) {
                response = Map.of("kind", "option", "optionId", selectedOptionId);
            }
            if (response == null || response.isEmpty()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "ATTEMPT_RESPONSE_REQUIRED",
                        "An exercise response is required.");
            }
            evidence = evidence == null ? Map.of() : Map.copyOf(evidence);
            Set<String> allowedEvidence = Set.of(
                    "responseTimeMs", "hintUsed", "hintLevel", "retryIndex", "confidence", "inputModality",
                    "practiceMode");
            if (!allowedEvidence.containsAll(evidence.keySet())
                    || !validInteger(evidence.get("responseTimeMs"), 0, Integer.MAX_VALUE)
                    || !validBoolean(evidence.get("hintUsed"))
                    || !validInteger(evidence.get("hintLevel"), 0, 5)
                    || !validInteger(evidence.get("retryIndex"), 0, 20)
                    || !validInteger(evidence.get("confidence"), 1, 5)
                    || !validModality(evidence.get("inputModality"))
                    || !validPracticeMode(evidence.get("practiceMode"))) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "ATTEMPT_EVIDENCE_INVALID",
                        "Attempt evidence contains an unsupported field or value.");
            }
            response = Map.copyOf(response);
        }

        private static boolean validInteger(Object value, int minimum, int maximum) {
            return value == null
                    || value instanceof Number number
                            && number.longValue() == number.doubleValue()
                            && number.longValue() >= minimum
                            && number.longValue() <= maximum;
        }

        private static boolean validBoolean(Object value) {
            return value == null || value instanceof Boolean;
        }

        private static boolean validModality(Object value) {
            return value == null
                    || value instanceof String modality
                            && Set.of("touch", "keyboard", "voice", "assistive_technology", "unknown")
                                    .contains(modality);
        }

        private static boolean validPracticeMode(Object value) {
            return value == null
                    || value instanceof String mode
                            && Set.of(
                                            "daily_quick_practice",
                                            "flashcards",
                                            "adaptive_learn",
                                            "practice_test",
                                            "match",
                                            "mistakes",
                                            "weak_concepts")
                                    .contains(mode);
        }
    }

    public record AttemptResult(
            UUID attemptId,
            UUID clientAttemptId,
            Instant acceptedAt,
            boolean correct,
            Scoring scoring,
            Feedback feedback,
            CourseProgress progress,
            String syncCursor) {}

    public record Scoring(int modelVersion, int earnedPoints, int maxPoints) {}

    public record Feedback(
            String messageCode,
            String correctOptionId,
            Map<String, Object> correctResponse,
            Map<String, String> explanation) {}

    public record CourseProgress(
            String courseId,
            int completedExerciseCount,
            int totalExerciseCount,
            Instant lastActivityAt,
            List<LessonProgress> lessonProgress,
            int completedLessonCount,
            int totalLessonCount,
            boolean completed) {}

    public record LessonProgress(
            String lessonId,
            int lessonVersion,
            String status,
            int completedExerciseCount,
            int totalExerciseCount) {}

    private record StoredAttempt(
            UUID id,
            UUID clientAttemptId,
            UUID idempotencyKey,
            String requestHash,
            String courseId,
            String lessonId,
            int lessonVersion,
            String exerciseId,
            String selectedOptionId,
            Map<String, Object> response,
            boolean correct,
            Instant acceptedAt) {}

    private record LessonCompletion(String lessonId, int lessonVersion) {}
}

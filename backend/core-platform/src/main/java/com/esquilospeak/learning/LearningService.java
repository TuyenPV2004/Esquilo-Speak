package com.esquilospeak.learning;

import com.esquilospeak.ApiException;
import com.esquilospeak.curriculumcontent.CurriculumContentService;
import com.esquilospeak.curriculumcontent.CurriculumContentService.ExerciseAnswer;
import com.esquilospeak.curriculumcontent.CurriculumContentService.LessonStructure;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
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

    public LearningService(
            JdbcClient jdbc, ObjectMapper objectMapper, CurriculumContentService contentService) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.contentService = contentService;
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

        ExerciseAnswer answer = contentService.exerciseAnswer(
                request.courseId(),
                request.lessonId(),
                request.lessonVersion(),
                request.exerciseId(),
                request.selectedOptionId());
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
                answer.correct(),
                Instant.now());
        try {
            jdbc.sql("""
                            insert into attempts (
                                id, learner_id, client_attempt_id, idempotency_key, request_hash,
                                course_id, lesson_id, lesson_version, exercise_id,
                                selected_option_id, correct, occurred_at, accepted_at, response_time_ms
                            ) values (
                                :id, :learnerId, :clientAttemptId, :idempotencyKey, :requestHash,
                                :courseId, :lessonId, :lessonVersion, :exerciseId,
                                :selectedOptionId, :correct, :occurredAt, :acceptedAt, :responseTimeMs
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
                    .param("selectedOptionId", created.selectedOptionId())
                    .param("correct", created.correct())
                    .param("occurredAt", Timestamp.from(request.occurredAt()))
                    .param("acceptedAt", Timestamp.from(created.acceptedAt()))
                    .param("responseTimeMs", request.responseTimeMs())
                    .update();
        } catch (DuplicateKeyException exception) {
            StoredAttempt raced = findExisting(learnerId, idempotencyKey, request.clientAttemptId());
            if (raced == null) {
                throw exception;
            }
            ensureSameRequest(raced, requestHash);
            return resultFor(learnerId, raced);
        }
        return resultFor(learnerId, created);
    }

    public CourseProgress progress(String learnerId, String courseId) {
        List<LessonStructure> lessons = contentService.courseStructure(courseId);
        Map<String, Integer> completedByLesson = new HashMap<>();
        jdbc.sql("""
                        select lesson_id, count(distinct exercise_id) as completed
                        from attempts
                        where learner_id = :learnerId
                          and course_id = :courseId
                          and correct = true
                        group by lesson_id
                        """)
                .param("learnerId", learnerId)
                .param("courseId", courseId)
                .query((rs, rowNum) -> Map.entry(rs.getString("lesson_id"), rs.getInt("completed")))
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
                            completedByLesson.getOrDefault(lesson.lessonId(), 0), lesson.exerciseCount());
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
        return new CourseProgress(courseId, completed, total, lastActivity, lessonProgress);
    }

    private AttemptResult resultFor(String learnerId, StoredAttempt attempt) {
        ExerciseAnswer answer = contentService.exerciseAnswer(
                attempt.courseId(),
                attempt.lessonId(),
                attempt.lessonVersion(),
                attempt.exerciseId(),
                attempt.selectedOptionId());
        Feedback feedback = new Feedback(
                attempt.correct()
                        ? Map.of("vi", "Chính xác!", "en", "Correct!")
                        : Map.of("vi", "Chưa chính xác. Hãy xem phần giải thích.", "en", "Not quite. Review the explanation."),
                answer.correctOptionId(),
                answer.explanation());
        return new AttemptResult(
                attempt.id(),
                attempt.clientAttemptId(),
                attempt.acceptedAt(),
                attempt.correct(),
                feedback,
                progress(learnerId, attempt.courseId()),
                attempt.acceptedAt().toEpochMilli() + ":" + attempt.id());
    }

    private StoredAttempt findExisting(String learnerId, UUID idempotencyKey, UUID clientAttemptId) {
        return jdbc.sql("""
                        select id, client_attempt_id, idempotency_key, request_hash, course_id,
                               lesson_id, lesson_version, exercise_id, selected_option_id,
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

    public record AttemptRequest(
            UUID clientAttemptId,
            String courseId,
            String lessonId,
            int lessonVersion,
            String exerciseId,
            String selectedOptionId,
            Instant occurredAt,
            Integer responseTimeMs) {}

    public record AttemptResult(
            UUID attemptId,
            UUID clientAttemptId,
            Instant acceptedAt,
            boolean correct,
            Feedback feedback,
            CourseProgress progress,
            String syncCursor) {}

    public record Feedback(
            Map<String, String> message,
            String correctOptionId,
            Map<String, String> explanation) {}

    public record CourseProgress(
            String courseId,
            int completedExerciseCount,
            int totalExerciseCount,
            Instant lastActivityAt,
            List<LessonProgress> lessonProgress) {}

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
            boolean correct,
            Instant acceptedAt) {}
}

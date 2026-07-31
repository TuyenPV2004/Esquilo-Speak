package com.esquilospeak.assessment;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
@Order(210)
public class AssessmentService implements AccountDataParticipant {

    private static final TypeReference<List<Question>> QUESTION_LIST = new TypeReference<>() {};
    private static final TypeReference<List<String>> ANSWER_LIST = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    AssessmentService(JdbcClient jdbc, ObjectMapper objectMapper, Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AssessmentDefinition definition(String courseId) {
        AssessmentConfiguration configuration = configurationForCourse(courseId);
        return new AssessmentDefinition(
                configuration.id(),
                configuration.courseId(),
                configuration.proficiency(),
                configuration.passScore(),
                configuration.questions());
    }

    @Transactional
    public AssessmentResult submit(
            UUID learnerId,
            UUID clientAttemptId,
            String assessmentId,
            List<String> answers) {
        AssessmentConfiguration configuration = configuration(assessmentId);
        if (answers.size() != configuration.answerKey().size()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ASSESSMENT_ANSWER_COUNT_INVALID",
                    "The placement assessment requires one answer for every question.");
        }
        String requestHash = hash(assessmentId + "\0" + String.join("\0", answers));
        AssessmentResult existing = find(learnerId, clientAttemptId, requestHash);
        if (existing != null) {
            return existing;
        }
        int correct = 0;
        for (int index = 0; index < configuration.answerKey().size(); index++) {
            if (configuration.answerKey().get(index).equals(answers.get(index))) {
                correct++;
            }
        }
        int score = correct * 100 / configuration.answerKey().size();
        boolean passed = score >= configuration.passScore();
        UUID attemptId = UUID.randomUUID();
        Instant now = clock.instant();
        ProficiencyReference proficiency = configuration.proficiency();
        jdbc.sql("""
                        insert into assessment_attempts (
                            id, learner_id, client_attempt_id, request_hash,
                            assessment_id, framework_code, framework_version,
                            level_code, score, passed, answer_summary, completed_at
                        ) values (
                            :id, :learnerId, :clientAttemptId, :requestHash,
                            :assessmentId, :frameworkCode, :frameworkVersion,
                            :levelCode, :score, :passed,
                            jsonb_build_object('answered', :answered, 'correct', :correct),
                            :completedAt
                        )
                        """)
                .param("id", attemptId)
                .param("learnerId", learnerId)
                .param("clientAttemptId", clientAttemptId)
                .param("requestHash", requestHash)
                .param("assessmentId", configuration.id())
                .param("frameworkCode", proficiency.frameworkCode())
                .param("frameworkVersion", proficiency.frameworkVersion())
                .param("levelCode", proficiency.levelCode())
                .param("score", score)
                .param("passed", passed)
                .param("answered", answers.size())
                .param("correct", correct)
                .param("completedAt", Timestamp.from(now))
                .update();
        CompletionRecord record = passed
                ? issueRecord(learnerId, attemptId, proficiency, now)
                : null;
        return new AssessmentResult(attemptId, proficiency, score, passed, record, now);
    }

    private CompletionRecord issueRecord(
            UUID learnerId,
            UUID attemptId,
            ProficiencyReference proficiency,
            Instant now) {
        UUID recordId = UUID.randomUUID();
        jdbc.sql("""
                        insert into completion_records (
                            id, learner_id, assessment_attempt_id,
                            framework_code, framework_version, level_code,
                            record_type, issued_at
                        ) values (
                            :id, :learnerId, :attemptId,
                            :frameworkCode, :frameworkVersion, :levelCode,
                            'non_accredited_completion', :issuedAt
                        )
                        """)
                .param("id", recordId)
                .param("learnerId", learnerId)
                .param("attemptId", attemptId)
                .param("frameworkCode", proficiency.frameworkCode())
                .param("frameworkVersion", proficiency.frameworkVersion())
                .param("levelCode", proficiency.levelCode())
                .param("issuedAt", Timestamp.from(now))
                .update();
        return new CompletionRecord(
                recordId, proficiency, "non_accredited_completion", now);
    }

    private AssessmentResult find(UUID learnerId, UUID clientAttemptId, String requestHash) {
        return jdbc.sql("""
                        select attempt.id, attempt.request_hash,
                               attempt.framework_code, attempt.framework_version,
                               attempt.level_code, attempt.score,
                               attempt.passed, attempt.completed_at,
                               record.id record_id, record.record_type, record.issued_at
                        from assessment_attempts attempt
                        left join completion_records record
                          on record.assessment_attempt_id = attempt.id
                        where attempt.learner_id = :learnerId
                          and attempt.client_attempt_id = :clientAttemptId
                        """)
                .param("learnerId", learnerId)
                .param("clientAttemptId", clientAttemptId)
                .query((rs, rowNum) -> {
                    if (!requestHash.equals(rs.getString("request_hash"))) {
                        throw new ApiException(
                                HttpStatus.CONFLICT,
                                "IDEMPOTENCY_CONFLICT",
                                "The client attempt identifier was reused with different answers.");
                    }
                    ProficiencyReference proficiency = new ProficiencyReference(
                            rs.getString("framework_code"),
                            rs.getString("framework_version"),
                            rs.getString("level_code"));
                    UUID recordId = rs.getObject("record_id", UUID.class);
                    CompletionRecord record = recordId == null
                            ? null
                            : new CompletionRecord(
                                    recordId,
                                    proficiency,
                                    rs.getString("record_type"),
                                    rs.getTimestamp("issued_at").toInstant());
                    return new AssessmentResult(
                            rs.getObject("id", UUID.class),
                            proficiency,
                            rs.getInt("score"),
                            rs.getBoolean("passed"),
                            record,
                            rs.getTimestamp("completed_at").toInstant());
                })
                .optional()
                .orElse(null);
    }

    private AssessmentConfiguration configurationForCourse(String courseId) {
        return jdbc.sql("""
                        select assessment.id, assessment.course_id,
                               assessment.framework_code, assessment.framework_version,
                               assessment.level_code, assessment.pass_score,
                               assessment.questions::text, assessment.answer_key::text
                        from placement_assessments assessment
                        join course_versions course_version
                          on course_version.course_id = assessment.course_id
                         and course_version.version = assessment.course_version
                        where assessment.course_id = :courseId
                          and assessment.active = true
                          and course_version.state = 'published'
                          and (course_version.effective_at is null
                               or course_version.effective_at <= now())
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> configuration(
                        rs.getString("id"),
                        rs.getString("course_id"),
                        rs.getString("framework_code"),
                        rs.getString("framework_version"),
                        rs.getString("level_code"),
                        rs.getInt("pass_score"),
                        rs.getString("questions"),
                        rs.getString("answer_key")))
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "PLACEMENT_ASSESSMENT_NOT_FOUND",
                        "No active placement assessment exists for the requested course."));
    }

    private AssessmentConfiguration configuration(String assessmentId) {
        return jdbc.sql("""
                        select id, course_id, framework_code, framework_version,
                               level_code, pass_score, questions::text, answer_key::text
                        from placement_assessments
                        where id = :assessmentId
                        """)
                .param("assessmentId", assessmentId)
                .query((rs, rowNum) -> configuration(
                        rs.getString("id"),
                        rs.getString("course_id"),
                        rs.getString("framework_code"),
                        rs.getString("framework_version"),
                        rs.getString("level_code"),
                        rs.getInt("pass_score"),
                        rs.getString("questions"),
                        rs.getString("answer_key")))
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "PLACEMENT_ASSESSMENT_NOT_FOUND",
                        "The requested placement assessment was not found."));
    }

    private AssessmentConfiguration configuration(
            String id,
            String courseId,
            String frameworkCode,
            String frameworkVersion,
            String levelCode,
            int passScore,
            String questions,
            String answerKey) {
        return new AssessmentConfiguration(
                id,
                courseId,
                new ProficiencyReference(frameworkCode, frameworkVersion, levelCode),
                passScore,
                read(questions, QUESTION_LIST),
                read(answerKey, ANSWER_LIST));
    }

    private <T> T read(String value, TypeReference<T> type) {
        try {
            return objectMapper.readValue(value, type);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored placement assessment JSON is invalid.", exception);
        }
    }

    @Override
    public String dataDomain() {
        return "assessment";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> attempts = jdbc.sql("""
                        select id, client_attempt_id, assessment_id,
                               framework_code, framework_version, level_code,
                               score, passed, completed_at
                        from assessment_attempts where learner_id = :learnerId
                        order by completed_at, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("id", rs.getObject("id", UUID.class));
                    item.put("clientAttemptId", rs.getObject("client_attempt_id", UUID.class));
                    item.put("assessmentId", rs.getString("assessment_id"));
                    item.put("proficiency", Map.of(
                            "frameworkCode", rs.getString("framework_code"),
                            "frameworkVersion", rs.getString("framework_version"),
                            "levelCode", rs.getString("level_code")));
                    item.put("score", rs.getInt("score"));
                    item.put("passed", rs.getBoolean("passed"));
                    item.put("completedAt", rs.getTimestamp("completed_at").toInstant());
                    return item;
                })
                .list();
        return Map.of("attempts", attempts);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from completion_records where learner_id = :learnerId")
                .param("learnerId", learnerId)
                .update();
        jdbc.sql("delete from assessment_attempts where learner_id = :learnerId")
                .param("learnerId", learnerId)
                .update();
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }

    public record Question(String id, String prompt, List<String> options) {}

    public record ProficiencyReference(
            String frameworkCode, String frameworkVersion, String levelCode) {}

    public record AssessmentDefinition(
            String id,
            String courseId,
            ProficiencyReference proficiency,
            int passScore,
            List<Question> questions) {}

    public record CompletionRecord(
            UUID id, ProficiencyReference proficiency, String type, Instant issuedAt) {}

    public record AssessmentResult(
            UUID attemptId,
            ProficiencyReference proficiency,
            int score,
            boolean passed,
            CompletionRecord completionRecord,
            Instant completedAt) {}

    private record AssessmentConfiguration(
            String id,
            String courseId,
            ProficiencyReference proficiency,
            int passScore,
            List<Question> questions,
            List<String> answerKey) {}
}

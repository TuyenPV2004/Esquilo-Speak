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

@Service
@Order(210)
public class AssessmentService implements AccountDataParticipant {

    private static final List<Question> QUESTIONS = List.of(
            new Question("a1-greeting", "Choose the greeting.", List.of("hello", "later", "thanks")),
            new Question("a1-name", "Complete: My ___ is Ana.", List.of("name", "day", "food")),
            new Question("a1-number", "Choose the number three.", List.of("two", "three", "four")),
            new Question("a1-goodbye", "Choose the farewell.", List.of("goodbye", "please", "water")));
    private static final List<String> ANSWERS = List.of("hello", "name", "three", "goodbye");

    private final JdbcClient jdbc;
    private final Clock clock;

    AssessmentService(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    public AssessmentDefinition definition() {
        return new AssessmentDefinition("placement-a1-v1", "A1", 80, QUESTIONS);
    }

    @Transactional
    public AssessmentResult submit(UUID learnerId, UUID clientAttemptId, List<String> answers) {
        if (answers.size() != ANSWERS.size()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ASSESSMENT_ANSWER_COUNT_INVALID",
                    "The placement assessment requires four answers.");
        }
        String requestHash = hash(String.join("\0", answers));
        AssessmentResult existing = find(learnerId, clientAttemptId, requestHash);
        if (existing != null) {
            return existing;
        }
        int correct = 0;
        for (int index = 0; index < ANSWERS.size(); index++) {
            if (ANSWERS.get(index).equals(answers.get(index))) {
                correct++;
            }
        }
        int score = correct * 25;
        boolean passed = score >= 80;
        UUID attemptId = UUID.randomUUID();
        Instant now = clock.instant();
        jdbc.sql("""
                        insert into assessment_attempts (
                            id, learner_id, client_attempt_id, request_hash, level,
                            score, passed, answer_summary, completed_at
                        ) values (
                            :id, :learnerId, :clientAttemptId, :requestHash, 'A1',
                            :score, :passed,
                            jsonb_build_object('answered', :answered, 'correct', :correct),
                            :completedAt
                        )
                        """)
                .param("id", attemptId)
                .param("learnerId", learnerId)
                .param("clientAttemptId", clientAttemptId)
                .param("requestHash", requestHash)
                .param("score", score)
                .param("passed", passed)
                .param("answered", answers.size())
                .param("correct", correct)
                .param("completedAt", Timestamp.from(now))
                .update();
        CompletionRecord record = passed ? issueRecord(learnerId, attemptId, now) : null;
        return new AssessmentResult(attemptId, "A1", score, passed, record, now);
    }

    private CompletionRecord issueRecord(UUID learnerId, UUID attemptId, Instant now) {
        UUID recordId = UUID.randomUUID();
        jdbc.sql("""
                        insert into completion_records (
                            id, learner_id, assessment_attempt_id, level,
                            record_type, issued_at
                        ) values (
                            :id, :learnerId, :attemptId, 'A1',
                            'non_accredited_completion', :issuedAt
                        )
                        """)
                .param("id", recordId)
                .param("learnerId", learnerId)
                .param("attemptId", attemptId)
                .param("issuedAt", Timestamp.from(now))
                .update();
        return new CompletionRecord(recordId, "A1", "non_accredited_completion", now);
    }

    private AssessmentResult find(UUID learnerId, UUID clientAttemptId, String requestHash) {
        return jdbc.sql("""
                        select attempt.id, attempt.request_hash, attempt.level, attempt.score,
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
                    UUID recordId = rs.getObject("record_id", UUID.class);
                    CompletionRecord record = recordId == null
                            ? null
                            : new CompletionRecord(
                                    recordId,
                                    rs.getString("level"),
                                    rs.getString("record_type"),
                                    rs.getTimestamp("issued_at").toInstant());
                    return new AssessmentResult(
                            rs.getObject("id", UUID.class),
                            rs.getString("level"),
                            rs.getInt("score"),
                            rs.getBoolean("passed"),
                            record,
                            rs.getTimestamp("completed_at").toInstant());
                })
                .optional()
                .orElse(null);
    }

    @Override
    public String dataDomain() {
        return "assessment";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> attempts = jdbc.sql("""
                        select id, client_attempt_id, level, score, passed, completed_at
                        from assessment_attempts where learner_id = :learnerId
                        order by completed_at, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("id", rs.getObject("id", UUID.class));
                    item.put("clientAttemptId", rs.getObject("client_attempt_id", UUID.class));
                    item.put("level", rs.getString("level"));
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

    public record AssessmentDefinition(
            String id, String level, int passScore, List<Question> questions) {}

    public record CompletionRecord(UUID id, String level, String type, Instant issuedAt) {}

    public record AssessmentResult(
            UUID attemptId,
            String level,
            int score,
            boolean passed,
            CompletionRecord completionRecord,
            Instant completedAt) {}
}

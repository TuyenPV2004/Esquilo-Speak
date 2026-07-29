package com.esquilospeak.learning;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.identityprofile.GuestAccountMerged;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
class LearningAccountDataParticipant implements AccountDataParticipant {

    private final JdbcClient jdbc;

    LearningAccountDataParticipant(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public String dataDomain() {
        return "learning";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> attempts = jdbc.sql("""
                        select id, client_attempt_id, course_id, lesson_id, lesson_version,
                               exercise_id, selected_option_id, correct, occurred_at, accepted_at,
                               response_time_ms
                        from attempts
                        where learner_id = :learnerId
                        order by accepted_at, id
                        """)
                .param("learnerId", learnerId.toString())
                .query((rs, rowNum) -> {
                    Map<String, Object> attempt = new LinkedHashMap<>();
                    attempt.put("attemptId", rs.getObject("id", UUID.class));
                    attempt.put("clientAttemptId", rs.getObject("client_attempt_id", UUID.class));
                    attempt.put("courseId", rs.getString("course_id"));
                    attempt.put("lessonId", rs.getString("lesson_id"));
                    attempt.put("lessonVersion", rs.getInt("lesson_version"));
                    attempt.put("exerciseId", rs.getString("exercise_id"));
                    attempt.put("selectedOptionId", rs.getString("selected_option_id"));
                    attempt.put("correct", rs.getBoolean("correct"));
                    attempt.put("occurredAt", rs.getTimestamp("occurred_at").toInstant());
                    attempt.put("acceptedAt", rs.getTimestamp("accepted_at").toInstant());
                    Object responseTime = rs.getObject("response_time_ms");
                    if (responseTime != null) {
                        attempt.put("responseTimeMs", responseTime);
                    }
                    return attempt;
                })
                .list();
        return Map.of("attempts", attempts);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from attempts where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
    }

    @EventListener
    void mergeGuestLearningData(GuestAccountMerged event) {
        String guestLearnerId = event.guestLearnerId().toString();
        String accountLearnerId = event.accountLearnerId().toString();
        boolean conflictingAttempt = jdbc.sql("""
                        select exists(
                            select 1
                            from attempts guest_attempt
                            join attempts account_attempt
                              on account_attempt.learner_id = :accountLearnerId
                             and (
                                  account_attempt.client_attempt_id = guest_attempt.client_attempt_id
                                  or account_attempt.idempotency_key = guest_attempt.idempotency_key
                             )
                            where guest_attempt.learner_id = :guestLearnerId
                              and account_attempt.request_hash <> guest_attempt.request_hash
                        )
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .query(Boolean.class)
                .single();
        if (conflictingAttempt) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "GUEST_PROGRESS_CONFLICT",
                    "Guest progress contains a mutation identifier with conflicting data.");
        }

        jdbc.sql("""
                        delete from attempts guest_attempt
                        where guest_attempt.learner_id = :guestLearnerId
                          and exists(
                              select 1
                              from attempts account_attempt
                              where account_attempt.learner_id = :accountLearnerId
                                and account_attempt.request_hash = guest_attempt.request_hash
                                and (
                                     account_attempt.client_attempt_id = guest_attempt.client_attempt_id
                                     or account_attempt.idempotency_key = guest_attempt.idempotency_key
                                )
                          )
                        """)
                .param("guestLearnerId", guestLearnerId)
                .param("accountLearnerId", accountLearnerId)
                .update();
        jdbc.sql("""
                        update attempts
                        set learner_id = :accountLearnerId
                        where learner_id = :guestLearnerId
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .update();
    }
}

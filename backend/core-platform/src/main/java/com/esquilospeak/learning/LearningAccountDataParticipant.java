package com.esquilospeak.learning;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.identityprofile.GuestAccountMerged;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Component
@Order(100)
class LearningAccountDataParticipant implements AccountDataParticipant {

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;

    LearningAccountDataParticipant(JdbcClient jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    @Override
    public String dataDomain() {
        return "learning";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> attempts = jdbc.sql("""
                        select id, client_attempt_id, course_id, lesson_id, lesson_version,
                               exercise_id, selected_option_id, response::text, correct, occurred_at, accepted_at,
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
                    attempt.put("response", readResponse(rs.getString("response")));
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
        List<Map<String, Object>> sessions = jdbc.sql("""
                        select id, client_session_id, course_id, content_version,
                               state, started_at, completed_at
                        from learning_sessions
                        where learner_id = :learnerId
                        order by started_at, id
                        """)
                .param("learnerId", learnerId.toString())
                .query((rs, rowNum) -> {
                    Map<String, Object> session = new LinkedHashMap<>();
                    session.put("sessionId", rs.getObject("id", UUID.class));
                    session.put("clientSessionId", rs.getObject("client_session_id", UUID.class));
                    session.put("courseId", rs.getString("course_id"));
                    session.put("contentVersion", rs.getInt("content_version"));
                    session.put("state", rs.getString("state"));
                    session.put("startedAt", rs.getTimestamp("started_at").toInstant());
                    if (rs.getTimestamp("completed_at") != null) {
                        session.put(
                                "completedAt",
                                rs.getTimestamp("completed_at").toInstant());
                    }
                    return session;
                })
                .list();
        return Map.of("attempts", attempts, "sessions", sessions);
    }

    private Map<String, Object> readResponse(String response) {
        try {
            return objectMapper.readValue(response, new TypeReference<>() {});
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored attempt response is invalid.", exception);
        }
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from learning_completions where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
        jdbc.sql("delete from attempts where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
        jdbc.sql("delete from learning_sessions where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
    }

    @EventListener
    @Order(Ordered.HIGHEST_PRECEDENCE + 10)
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
        jdbc.sql("""
                        update attempts moved_attempt
                        set session_id = account_session.id
                        from learning_sessions guest_session
                        join learning_sessions account_session
                          on account_session.learner_id = :accountLearnerId
                         and (
                              account_session.client_session_id = guest_session.client_session_id
                              or account_session.idempotency_key = guest_session.idempotency_key
                         )
                        where guest_session.learner_id = :guestLearnerId
                          and moved_attempt.session_id = guest_session.id
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .update();
        jdbc.sql("""
                        delete from learning_sessions guest
                        where guest.learner_id = :guestLearnerId
                          and exists (
                              select 1 from learning_sessions account
                              where account.learner_id = :accountLearnerId
                                and (
                                    account.client_session_id = guest.client_session_id
                                    or account.idempotency_key = guest.idempotency_key
                                )
                          )
                        """)
                .param("guestLearnerId", guestLearnerId)
                .param("accountLearnerId", accountLearnerId)
                .update();
        jdbc.sql("""
                        update learning_sessions
                        set learner_id = :accountLearnerId
                        where learner_id = :guestLearnerId
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .update();
        jdbc.sql("""
                        insert into learning_completions (
                            learner_id, course_id, lesson_id, lesson_version,
                            active, completed_at, updated_at
                        )
                        select :accountLearnerId, course_id, lesson_id, lesson_version,
                               active, completed_at, updated_at
                        from learning_completions
                        where learner_id = :guestLearnerId
                        on conflict (learner_id, course_id, lesson_id) do update
                        set active = learning_completions.active or excluded.active,
                            lesson_version = greatest(
                                learning_completions.lesson_version,
                                excluded.lesson_version),
                            completed_at = coalesce(
                                learning_completions.completed_at,
                                excluded.completed_at),
                            updated_at = greatest(
                                learning_completions.updated_at,
                                excluded.updated_at)
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .update();
        jdbc.sql("delete from learning_completions where learner_id = :guestLearnerId")
                .param("guestLearnerId", guestLearnerId)
                .update();
    }
}

package com.esquilospeak.learning;

import com.esquilospeak.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LearningSessionService {

    private final JdbcClient jdbc;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public LearningSessionService(
            JdbcClient jdbc, ApplicationEventPublisher events, Clock clock) {
        this.jdbc = jdbc;
        this.events = events;
        this.clock = clock;
    }

    @Transactional
    public SessionResult start(
            String learnerId,
            UUID idempotencyKey,
            UUID clientSessionId,
            String courseId,
            int contentVersion) {
        String requestHash = hash(clientSessionId + ":" + courseId + ":" + contentVersion);
        SessionResult existing = findByMutation(learnerId, idempotencyKey, clientSessionId);
        if (existing != null) {
            String existingHash = jdbc.sql("""
                            select request_hash
                            from learning_sessions
                            where id = :id
                            """)
                    .param("id", existing.sessionId())
                    .query(String.class)
                    .single();
            if (!existingHash.equals(requestHash)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "IDEMPOTENCY_CONFLICT",
                        "The session mutation identifier was reused with different data.");
            }
            return existing;
        }
        boolean contentExists = jdbc.sql("""
                        select exists(
                            select 1
                            from course_versions
                            where course_id = :courseId and version = :contentVersion
                              and state in ('published', 'retired')
                        )
                        """)
                .param("courseId", courseId)
                .param("contentVersion", contentVersion)
                .query(Boolean.class)
                .single();
        if (!contentExists) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "CONTENT_VERSION_INVALID",
                    "The requested course content version is not available.");
        }
        Instant startedAt = clock.instant();
        SessionResult created = new SessionResult(
                UUID.randomUUID(),
                clientSessionId,
                courseId,
                contentVersion,
                "active",
                startedAt,
                null);
        jdbc.sql("""
                        insert into learning_sessions (
                            id, learner_id, client_session_id, idempotency_key, request_hash,
                            course_id, content_version, state, started_at
                        ) values (
                            :id, :learnerId, :clientSessionId, :idempotencyKey, :requestHash,
                            :courseId, :contentVersion, 'active', :startedAt
                        )
                        """)
                .param("id", created.sessionId())
                .param("learnerId", learnerId)
                .param("clientSessionId", clientSessionId)
                .param("idempotencyKey", idempotencyKey)
                .param("requestHash", requestHash)
                .param("courseId", courseId)
                .param("contentVersion", contentVersion)
                .param("startedAt", Timestamp.from(startedAt))
                .update();
        publish(learnerId, created, startedAt);
        return created;
    }

    @Transactional
    public SessionResult complete(String learnerId, UUID sessionId) {
        SessionResult existing = findById(learnerId, sessionId);
        if (existing == null) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND,
                    "LEARNING_SESSION_NOT_FOUND",
                    "The learning session was not found.");
        }
        if ("completed".equals(existing.state())) {
            return existing;
        }
        Instant completedAt = clock.instant();
        jdbc.sql("""
                        update learning_sessions
                        set state = 'completed', completed_at = :completedAt
                        where id = :sessionId and learner_id = :learnerId
                        """)
                .param("completedAt", Timestamp.from(completedAt))
                .param("sessionId", sessionId)
                .param("learnerId", learnerId)
                .update();
        SessionResult completed = new SessionResult(
                existing.sessionId(),
                existing.clientSessionId(),
                existing.courseId(),
                existing.contentVersion(),
                "completed",
                existing.startedAt(),
                completedAt);
        publish(learnerId, completed, completedAt);
        return completed;
    }

    private SessionResult findByMutation(
            String learnerId, UUID idempotencyKey, UUID clientSessionId) {
        return jdbc.sql("""
                        select id, client_session_id, course_id, content_version,
                               state, started_at, completed_at
                        from learning_sessions
                        where learner_id = :learnerId
                          and (idempotency_key = :idempotencyKey
                               or client_session_id = :clientSessionId)
                        limit 1
                        """)
                .param("learnerId", learnerId)
                .param("idempotencyKey", idempotencyKey)
                .param("clientSessionId", clientSessionId)
                .query(this::map)
                .optional()
                .orElse(null);
    }

    private SessionResult findById(String learnerId, UUID sessionId) {
        return jdbc.sql("""
                        select id, client_session_id, course_id, content_version,
                               state, started_at, completed_at
                        from learning_sessions
                        where learner_id = :learnerId and id = :sessionId
                        """)
                .param("learnerId", learnerId)
                .param("sessionId", sessionId)
                .query(this::map)
                .optional()
                .orElse(null);
    }

    private SessionResult map(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
        Timestamp completedAt = rs.getTimestamp("completed_at");
        return new SessionResult(
                rs.getObject("id", UUID.class),
                rs.getObject("client_session_id", UUID.class),
                rs.getString("course_id"),
                rs.getInt("content_version"),
                rs.getString("state"),
                rs.getTimestamp("started_at").toInstant(),
                completedAt == null ? null : completedAt.toInstant());
    }

    private void publish(String learnerId, SessionResult session, Instant changedAt) {
        events.publishEvent(new LearningSessionChanged(
                learnerId,
                session.sessionId(),
                session.clientSessionId(),
                session.courseId(),
                session.contentVersion(),
                session.state(),
                changedAt));
    }

    private String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available.", exception);
        }
    }

    public record SessionResult(
            UUID sessionId,
            UUID clientSessionId,
            String courseId,
            int contentVersion,
            String state,
            Instant startedAt,
            Instant completedAt) {}
}

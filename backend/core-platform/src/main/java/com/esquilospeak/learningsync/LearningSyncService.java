package com.esquilospeak.learningsync;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.identityprofile.GuestAccountMerged;
import com.esquilospeak.learning.AttemptAccepted;
import com.esquilospeak.learning.CompletionChanged;
import com.esquilospeak.learning.LearningService;
import com.esquilospeak.learning.LearningSessionChanged;
import com.esquilospeak.mastery.MasteryUpdated;
import com.esquilospeak.reviewscheduler.ReviewScheduled;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
@Order(10)
public class LearningSyncService implements AccountDataParticipant {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final LearningService learningService;
    private final Clock clock;
    private final SyncCursorService cursors;

    public LearningSyncService(
            JdbcClient jdbc,
            ObjectMapper objectMapper,
            LearningService learningService,
            Clock clock,
            SyncCursorService cursors) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.learningService = learningService;
        this.clock = clock;
        this.cursors = cursors;
    }

    @Transactional
    public PushResult push(String learnerId, PushRequest request) {
        long base = cursors.decode(request.baseCursor());
        long before = cursors.currentSequence(learnerId);
        cursors.ensureNotAhead(base, before);
        List<MutationResult> results = new ArrayList<>();
        for (PushMutation mutation : request.mutations()) {
            results.add(apply(learnerId, mutation));
        }
        return new PushResult(
                request.clientBatchId(),
                base < before,
                cursors.currentCursor(learnerId),
                results);
    }

    public PullResult pull(String learnerId, String cursor, int limit) {
        long after = cursors.decode(cursor);
        long current = cursors.currentSequence(learnerId);
        cursors.ensureNotAhead(after, current);
        List<SyncChange> changes = jdbc.sql("""
                        select sequence_id, entity_type, entity_id, operation,
                               payload::text, occurred_at
                        from sync_changes
                        where learner_id = :learnerId and sequence_id > :after
                        order by sequence_id
                        limit :fetchLimit
                        """)
                .param("learnerId", learnerId)
                .param("after", after)
                .param("fetchLimit", limit + 1)
                .query((rs, rowNum) -> new SyncChange(
                        rs.getString("entity_type"),
                        rs.getString("entity_id"),
                        rs.getString("operation"),
                        readMap(rs.getString("payload")),
                        rs.getTimestamp("occurred_at").toInstant()))
                .list();
        boolean hasMore = changes.size() > limit;
        List<SyncChange> page = hasMore ? changes.subList(0, limit) : changes;
        long next = page.isEmpty()
                ? after
                : jdbc.sql("""
                                select sequence_id
                                from sync_changes
                                where learner_id = :learnerId and sequence_id > :after
                                order by sequence_id
                                offset :offset rows fetch first 1 row only
                                """)
                        .param("learnerId", learnerId)
                        .param("after", after)
                        .param("offset", page.size() - 1)
                        .query(Long.class)
                        .single();
        return new PullResult(cursors.encode(next), hasMore, List.copyOf(page));
    }

    private MutationResult apply(String learnerId, PushMutation mutation) {
        if (!"attempt.submit".equals(mutation.type())) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "SYNC_MUTATION_UNSUPPORTED",
                    "Only attempt.submit mutations are supported by this contract version.");
        }
        LearningService.AttemptRequest attempt;
        try {
            attempt = objectMapper.convertValue(
                    mutation.payload(), LearningService.AttemptRequest.class);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "SYNC_MUTATION_INVALID",
                    "The attempt mutation payload is invalid.");
        }
        String requestHash = hash(mutation.type(), mutation.idempotencyKey(), attempt);
        int reserved = jdbc.sql("""
                        insert into sync_mutations (
                            learner_id, client_mutation_id, mutation_type,
                            request_hash, state
                        ) values (
                            :learnerId, :clientMutationId, :mutationType,
                            :requestHash, 'processing'
                        )
                        on conflict (learner_id, client_mutation_id) do nothing
                        """)
                .param("learnerId", learnerId)
                .param("clientMutationId", mutation.clientMutationId())
                .param("mutationType", mutation.type())
                .param("requestHash", requestHash)
                .update();
        if (reserved == 0) {
            StoredMutation existing = findMutation(learnerId, mutation.clientMutationId());
            if (!existing.requestHash().equals(requestHash)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "SYNC_MUTATION_CONFLICT",
                        "The client mutation ID was reused with different data.");
            }
            if (!"applied".equals(existing.state()) || existing.result() == null) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "SYNC_MUTATION_IN_PROGRESS",
                        "The mutation is already being processed; retry with the same identifier.");
            }
            return new MutationResult(
                    mutation.clientMutationId(), "replayed", existing.result());
        }
        LearningService.AttemptResult accepted =
                learningService.submit(learnerId, mutation.idempotencyKey(), attempt);
        Map<String, Object> result = objectMapper.convertValue(accepted, MAP_TYPE);
        jdbc.sql("""
                        update sync_mutations
                        set state = 'applied',
                            result_payload = cast(:result as jsonb),
                            applied_at = :appliedAt
                        where learner_id = :learnerId
                          and client_mutation_id = :clientMutationId
                        """)
                .param("result", writeJson(result))
                .param("appliedAt", Timestamp.from(clock.instant()))
                .param("learnerId", learnerId)
                .param("clientMutationId", mutation.clientMutationId())
                .update();
        return new MutationResult(mutation.clientMutationId(), "applied", result);
    }

    @EventListener
    public void onAttempt(AttemptAccepted event) {
        append(
                event.learnerId(),
                "attempt",
                event.attemptId().toString(),
                "upsert",
                Map.of(
                        "attemptId", event.attemptId(),
                        "clientAttemptId", event.clientAttemptId(),
                        "courseId", event.courseId(),
                        "lessonId", event.lessonId(),
                        "lessonVersion", event.lessonVersion(),
                        "exerciseId", event.exerciseId(),
                        "correct", event.correct(),
                        "acceptedAt", event.acceptedAt()),
                event.acceptedAt());
    }

    @EventListener
    public void onMastery(MasteryUpdated event) {
        append(
                event.learnerId(),
                "mastery",
                event.conceptId(),
                "upsert",
                Map.of(
                        "conceptId", event.conceptId(),
                        "modelVersion", event.modelVersion(),
                        "score", event.score(),
                        "correctEvidenceCount", event.correctEvidenceCount(),
                        "evidenceCount", event.evidenceCount(),
                        "updatedAt", event.updatedAt()),
                event.updatedAt());
    }

    @EventListener
    public void onReview(ReviewScheduled event) {
        append(
                event.learnerId(),
                "reviewSchedule",
                event.conceptId(),
                "upsert",
                Map.of(
                        "conceptId", event.conceptId(),
                        "modelVersion", event.modelVersion(),
                        "dueAt", event.dueAt(),
                        "intervalDays", event.intervalDays(),
                        "repetitions", event.repetitions(),
                        "lastResult", event.lastResult()),
                event.updatedAt());
    }

    @EventListener
    public void onCompletion(CompletionChanged event) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("courseId", event.courseId());
        payload.put("lessonId", event.lessonId());
        payload.put("lessonVersion", event.lessonVersion());
        payload.put("completed", event.completed());
        payload.put("changedAt", event.changedAt());
        append(
                event.learnerId(),
                "lessonCompletion",
                event.courseId() + ":" + event.lessonId(),
                event.completed() ? "upsert" : "delete",
                payload,
                event.changedAt());
    }

    @EventListener
    public void onSession(LearningSessionChanged event) {
        append(
                event.learnerId(),
                "learningSession",
                event.sessionId().toString(),
                "upsert",
                Map.of(
                        "sessionId", event.sessionId(),
                        "clientSessionId", event.clientSessionId(),
                        "courseId", event.courseId(),
                        "contentVersion", event.contentVersion(),
                        "state", event.state(),
                        "changedAt", event.changedAt()),
                event.changedAt());
    }

    private void append(
            String learnerId,
            String entityType,
            String entityId,
            String operation,
            Map<String, Object> payload,
            Instant occurredAt) {
        jdbc.sql("""
                        insert into sync_changes (
                            learner_id, entity_type, entity_id, operation, payload, occurred_at
                        ) values (
                            :learnerId, :entityType, :entityId, :operation,
                            cast(:payload as jsonb), :occurredAt
                        )
                        """)
                .param("learnerId", learnerId)
                .param("entityType", entityType)
                .param("entityId", entityId)
                .param("operation", operation)
                .param("payload", writeJson(payload))
                .param("occurredAt", Timestamp.from(occurredAt))
                .update();
    }

    private StoredMutation findMutation(String learnerId, UUID mutationId) {
        return jdbc.sql("""
                        select request_hash, state, result_payload::text
                        from sync_mutations
                        where learner_id = :learnerId
                          and client_mutation_id = :mutationId
                        """)
                .param("learnerId", learnerId)
                .param("mutationId", mutationId)
                .query((rs, rowNum) -> {
                    String payload = rs.getString("result_payload");
                    return new StoredMutation(
                            rs.getString("request_hash"),
                            rs.getString("state"),
                            payload == null ? null : readMap(payload));
                })
                .single();
    }

    private String hash(String type, UUID idempotencyKey, Object payload) {
        try {
            byte[] bytes = objectMapper
                    .writeValueAsString(List.of(type, idempotencyKey, payload))
                    .getBytes(StandardCharsets.UTF_8);
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (JacksonException | NoSuchAlgorithmException exception) {
            throw new IllegalStateException("Could not hash the sync mutation.", exception);
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize sync data.", exception);
        }
    }

    private Map<String, Object> readMap(String value) {
        try {
            return objectMapper.readValue(value, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored sync data is invalid.", exception);
        }
    }

    @Override
    public String dataDomain() {
        return "learningSync";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        return Map.of("currentCursor", cursors.currentCursor(learnerId.toString()));
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from sync_changes where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
        jdbc.sql("delete from sync_mutations where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
    }

    @EventListener
    @Order(Ordered.LOWEST_PRECEDENCE)
    @Transactional
    void mergeGuestData(GuestAccountMerged event) {
        String guestId = event.guestLearnerId().toString();
        String accountId = event.accountLearnerId().toString();
        boolean conflict = jdbc.sql("""
                        select exists(
                            select 1
                            from sync_mutations guest
                            join sync_mutations account
                              on account.learner_id = :accountId
                             and account.client_mutation_id = guest.client_mutation_id
                            where guest.learner_id = :guestId
                              and guest.request_hash <> account.request_hash
                        )
                        """)
                .param("accountId", accountId)
                .param("guestId", guestId)
                .query(Boolean.class)
                .single();
        if (conflict) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "GUEST_SYNC_CONFLICT",
                    "Guest sync history conflicts with the account history.");
        }
        jdbc.sql("""
                        delete from sync_mutations guest
                        where guest.learner_id = :guestId
                          and exists (
                              select 1 from sync_mutations account
                              where account.learner_id = :accountId
                                and account.client_mutation_id = guest.client_mutation_id
                          )
                        """)
                .param("guestId", guestId)
                .param("accountId", accountId)
                .update();
        jdbc.sql("update sync_mutations set learner_id = :accountId where learner_id = :guestId")
                .param("accountId", accountId)
                .param("guestId", guestId)
                .update();
        jdbc.sql("update sync_changes set learner_id = :accountId where learner_id = :guestId")
                .param("accountId", accountId)
                .param("guestId", guestId)
                .update();
    }

    public record PushRequest(
            UUID clientBatchId, String baseCursor, List<PushMutation> mutations) {}

    public record PushMutation(
            UUID clientMutationId,
            String type,
            UUID idempotencyKey,
            Map<String, Object> payload) {}

    public record PushResult(
            UUID clientBatchId,
            boolean rebased,
            String nextCursor,
            List<MutationResult> results) {}

    public record MutationResult(
            UUID clientMutationId, String status, Map<String, Object> result) {}

    public record PullResult(String nextCursor, boolean hasMore, List<SyncChange> changes) {}

    public record SyncChange(
            String entityType,
            String entityId,
            String operation,
            Map<String, Object> payload,
            Instant occurredAt) {}

    private record StoredMutation(
            String requestHash, String state, Map<String, Object> result) {}
}

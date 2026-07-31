package com.esquilospeak.identityprofile;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.IdentityProfileService.LearnerContext;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class PrivacyRequestService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final IdentityProfileService identityProfileService;
    private final List<AccountDataParticipant> dataParticipants;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final long exportTargetDays;
    private final long deletionTargetDays;
    private final long inactiveGuestDays;

    public PrivacyRequestService(
            JdbcClient jdbc,
            IdentityProfileService identityProfileService,
            List<AccountDataParticipant> dataParticipants,
            ObjectMapper objectMapper,
            Clock clock,
            @Value("${esquilospeak.privacy.export-target-days}") long exportTargetDays,
            @Value("${esquilospeak.privacy.deletion-target-days}") long deletionTargetDays,
            @Value("${esquilospeak.privacy.inactive-guest-days}") long inactiveGuestDays) {
        this.jdbc = jdbc;
        this.identityProfileService = identityProfileService;
        this.dataParticipants = dataParticipants;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.exportTargetDays = exportTargetDays;
        this.deletionTargetDays = deletionTargetDays;
        this.inactiveGuestDays = inactiveGuestDays;
    }

    @Transactional
    public PrivacyRequest requestExport(LearnerContext learner, UUID idempotencyKey) {
        return request(learner, RequestType.EXPORT, idempotencyKey);
    }

    @Transactional
    public PrivacyRequest requestDeletion(LearnerContext learner, UUID idempotencyKey) {
        PrivacyRequest existing = findByIdempotency(
                learner.learnerId(), RequestType.DELETION, idempotencyKey);
        if (existing != null) {
            return existing;
        }
        PrivacyRequest created = insertRequest(learner.learnerId(), RequestType.DELETION, idempotencyKey);
        identityProfileService.markDeletionPending(learner.learnerId());
        identityProfileService.recordAudit(
                learner.learnerId(),
                "PRIVACY_REQUEST_CREATED",
                Map.of("requestId", created.requestId().toString(), "requestType", "deletion"));
        return created;
    }

    @Transactional(readOnly = true)
    public PrivacyRequest status(LearnerContext learner, UUID requestId) {
        return jdbc.sql("""
                        select id, learner_id, request_type, state, requested_at, target_at,
                               completed_at, artifact::text, artifact_expires_at, failure_code
                        from privacy_requests
                        where id = :requestId and learner_id = :learnerId
                        """)
                .param("requestId", requestId)
                .param("learnerId", learner.learnerId())
                .query(this::mapRequest)
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "PRIVACY_REQUEST_NOT_FOUND",
                        "The privacy request was not found."));
    }

    @Transactional
    public boolean processNext() {
        UUID requestId = jdbc.sql("""
                        select id
                        from privacy_requests
                        where state = 'requested'
                        order by requested_at
                        for update skip locked
                        limit 1
                        """)
                .query(UUID.class)
                .optional()
                .orElse(null);
        if (requestId == null) {
            return false;
        }
        jdbc.sql("update privacy_requests set state = 'processing' where id = :requestId")
                .param("requestId", requestId)
                .update();
        PrivacyRequest request = findById(requestId);
        if (request.requestType() == RequestType.EXPORT) {
            processExport(request);
        } else {
            processDeletion(request);
        }
        return true;
    }

    @Transactional
    public boolean requestNextInactiveGuestDeletion() {
        UUID learnerId = jdbc.sql("""
                        select l.id
                        from learners l
                        join identity_subjects s on s.learner_id = l.id
                        where l.state = 'active'
                          and s.actor_type = 'guest'
                          and l.last_activity_at < :inactiveBefore
                          and not exists(
                              select 1
                              from privacy_requests request
                              where request.learner_id = l.id
                                and request.request_type = 'deletion'
                                and request.state in ('requested', 'processing', 'completed')
                          )
                        order by l.last_activity_at
                        for update of l skip locked
                        limit 1
                        """)
                .param("inactiveBefore", Timestamp.from(clock.instant().minus(inactiveGuestDays, ChronoUnit.DAYS)))
                .query(UUID.class)
                .optional()
                .orElse(null);
        if (learnerId == null) {
            return false;
        }
        PrivacyRequest created =
                insertRequest(learnerId, RequestType.DELETION, UUID.randomUUID());
        identityProfileService.markDeletionPending(learnerId);
        identityProfileService.recordAudit(
                learnerId,
                "INACTIVE_GUEST_DELETION_SCHEDULED",
                Map.of("requestId", created.requestId().toString()));
        return true;
    }

    private PrivacyRequest request(
            LearnerContext learner,
            RequestType requestType,
            UUID idempotencyKey) {
        PrivacyRequest existing =
                findByIdempotency(learner.learnerId(), requestType, idempotencyKey);
        if (existing != null) {
            return existing;
        }
        PrivacyRequest created = insertRequest(learner.learnerId(), requestType, idempotencyKey);
        identityProfileService.recordAudit(
                learner.learnerId(),
                "PRIVACY_REQUEST_CREATED",
                Map.of(
                        "requestId", created.requestId().toString(),
                        "requestType", requestType.value));
        return created;
    }

    private PrivacyRequest insertRequest(
            UUID learnerId,
            RequestType requestType,
            UUID idempotencyKey) {
        Instant now = clock.instant();
        Instant targetAt = requestType == RequestType.EXPORT
                ? now.plus(exportTargetDays, ChronoUnit.DAYS)
                : now.plus(deletionTargetDays, ChronoUnit.DAYS);
        UUID requestId = UUID.randomUUID();
        jdbc.sql("""
                        insert into privacy_requests (
                            id, learner_id, request_type, state, idempotency_key,
                            requested_at, target_at
                        ) values (
                            :id, :learnerId, :requestType, 'requested', :idempotencyKey,
                            :requestedAt, :targetAt
                        )
                        """)
                .param("id", requestId)
                .param("learnerId", learnerId)
                .param("requestType", requestType.value)
                .param("idempotencyKey", idempotencyKey)
                .param("requestedAt", Timestamp.from(now))
                .param("targetAt", Timestamp.from(targetAt))
                .update();
        return new PrivacyRequest(
                requestId,
                learnerId,
                requestType,
                RequestState.REQUESTED,
                now,
                targetAt,
                null,
                null,
                null,
                null);
    }

    private void processExport(PrivacyRequest request) {
        Map<String, Object> export = new LinkedHashMap<>();
        export.put("identityProfile", identityProfileService.exportIdentityData(request.learnerId()));
        for (AccountDataParticipant participant : dataParticipants) {
            export.put(participant.dataDomain(), participant.exportData(request.learnerId()));
        }
        Instant now = clock.instant();
        jdbc.sql("""
                        update privacy_requests
                        set state = 'completed',
                            completed_at = :completedAt,
                            artifact = cast(:artifact as jsonb),
                            artifact_expires_at = :artifactExpiresAt
                        where id = :requestId and state = 'processing'
                        """)
                .param("completedAt", Timestamp.from(now))
                .param("artifact", writeJson(export))
                .param("artifactExpiresAt", Timestamp.from(now.plus(7, ChronoUnit.DAYS)))
                .param("requestId", request.requestId())
                .update();
        identityProfileService.recordAudit(
                request.learnerId(),
                "ACCOUNT_EXPORT_COMPLETED",
                Map.of("requestId", request.requestId().toString()));
    }

    private void processDeletion(PrivacyRequest request) {
        for (AccountDataParticipant participant : dataParticipants) {
            participant.deleteData(request.learnerId());
        }
        identityProfileService.completeDeletion(request.learnerId());
        Instant now = clock.instant();
        jdbc.sql("""
                        update privacy_requests
                        set state = 'completed',
                            completed_at = :completedAt,
                            artifact = null,
                            artifact_expires_at = null
                        where id = :requestId and state = 'processing'
                        """)
                .param("completedAt", Timestamp.from(now))
                .param("requestId", request.requestId())
                .update();
    }

    private PrivacyRequest findByIdempotency(
            UUID learnerId,
            RequestType requestType,
            UUID idempotencyKey) {
        return jdbc.sql("""
                        select id, learner_id, request_type, state, requested_at, target_at,
                               completed_at, artifact::text, artifact_expires_at, failure_code
                        from privacy_requests
                        where learner_id = :learnerId
                          and request_type = :requestType
                          and idempotency_key = :idempotencyKey
                        """)
                .param("learnerId", learnerId)
                .param("requestType", requestType.value)
                .param("idempotencyKey", idempotencyKey)
                .query(this::mapRequest)
                .optional()
                .orElse(null);
    }

    private PrivacyRequest findById(UUID requestId) {
        return jdbc.sql("""
                        select id, learner_id, request_type, state, requested_at, target_at,
                               completed_at, artifact::text, artifact_expires_at, failure_code
                        from privacy_requests
                        where id = :requestId
                        """)
                .param("requestId", requestId)
                .query(this::mapRequest)
                .single();
    }

    private PrivacyRequest mapRequest(java.sql.ResultSet rs, int rowNumber)
            throws java.sql.SQLException {
        Timestamp completedAt = rs.getTimestamp("completed_at");
        Timestamp artifactExpiresAt = rs.getTimestamp("artifact_expires_at");
        String artifact = rs.getString("artifact");
        return new PrivacyRequest(
                rs.getObject("id", UUID.class),
                rs.getObject("learner_id", UUID.class),
                RequestType.fromValue(rs.getString("request_type")),
                RequestState.fromValue(rs.getString("state")),
                rs.getTimestamp("requested_at").toInstant(),
                rs.getTimestamp("target_at").toInstant(),
                completedAt == null ? null : completedAt.toInstant(),
                artifact == null ? null : readMap(artifact),
                artifactExpiresAt == null ? null : artifactExpiresAt.toInstant(),
                rs.getString("failure_code"));
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize privacy export.", exception);
        }
    }

    private Map<String, Object> readMap(String value) {
        try {
            return objectMapper.readValue(value, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored privacy export is not valid JSON.", exception);
        }
    }

    public enum RequestType {
        EXPORT("export"),
        DELETION("deletion");

        private final String value;

        RequestType(String value) {
            this.value = value;
        }

        static RequestType fromValue(String value) {
            for (RequestType type : values()) {
                if (type.value.equals(value)) {
                    return type;
                }
            }
            throw new IllegalStateException("Unknown privacy request type: " + value);
        }
    }

    public enum RequestState {
        REQUESTED("requested"),
        PROCESSING("processing"),
        COMPLETED("completed"),
        FAILED("failed");

        private final String value;

        RequestState(String value) {
            this.value = value;
        }

        static RequestState fromValue(String value) {
            for (RequestState state : values()) {
                if (state.value.equals(value)) {
                    return state;
                }
            }
            throw new IllegalStateException("Unknown privacy request state: " + value);
        }
    }

    public record PrivacyRequest(
            UUID requestId,
            UUID learnerId,
            RequestType requestType,
            RequestState state,
            Instant requestedAt,
            Instant targetAt,
            Instant completedAt,
            Map<String, Object> artifact,
            Instant artifactExpiresAt,
            String failureCode) {}
}

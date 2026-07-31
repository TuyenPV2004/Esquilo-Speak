package com.esquilospeak.identityprofile;

import com.esquilospeak.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class IdentityProfileService {

    private static final String REQUIRED_SERVICE_POLICY = "p0-2026-07-30";
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public IdentityProfileService(
            JdbcClient jdbc,
            ObjectMapper objectMapper,
            ApplicationEventPublisher events,
            Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.events = events;
        this.clock = clock;
    }

    @Transactional
    public LearnerContext resolve(Jwt jwt) {
        String issuer = jwt.getIssuer() == null ? null : jwt.getIssuer().toString();
        String subject = jwt.getSubject();
        ActorType actorType = ActorType.fromClaim(jwt.getClaimAsString("actor_type"));
        if (issuer == null || issuer.isBlank() || subject == null || subject.isBlank()) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "INVALID_IDENTITY_TOKEN",
                    "The access token must contain a valid issuer and subject.");
        }

        String subjectHash = hash(issuer + "\0" + subject);
        LearnerContext existing = findBySubjectHash(subjectHash);
        if (existing != null) {
            ensureActive(existing);
            touch(existing.learnerId());
            return existing;
        }

        Instant now = clock.instant();
        UUID learnerId = UUID.randomUUID();
        jdbc.sql("""
                        insert into learners (
                            id, state, created_at, updated_at, last_activity_at
                        ) values (
                            :id, 'active', :now, :now, :now
                        )
                        """)
                .param("id", learnerId)
                .param("now", Timestamp.from(now))
                .update();
        jdbc.sql("""
                        insert into learner_profiles (
                            learner_id, preferences, updated_at
                        ) values (
                            :learnerId, '{}'::jsonb, :now
                        )
                        """)
                .param("learnerId", learnerId)
                .param("now", Timestamp.from(now))
                .update();
        int inserted = jdbc.sql("""
                        insert into identity_subjects (
                            subject_hash, issuer, learner_id, actor_type, created_at
                        ) values (
                            :subjectHash, :issuer, :learnerId, :actorType, :now
                        )
                        on conflict (subject_hash) do nothing
                        """)
                .param("subjectHash", subjectHash)
                .param("issuer", issuer)
                .param("learnerId", learnerId)
                .param("actorType", actorType.value)
                .param("now", Timestamp.from(now))
                .update();
        if (inserted == 0) {
            jdbc.sql("delete from learner_profiles where learner_id = :learnerId")
                    .param("learnerId", learnerId)
                    .update();
            jdbc.sql("delete from learners where id = :learnerId")
                    .param("learnerId", learnerId)
                    .update();
            LearnerContext raced = findBySubjectHash(subjectHash);
            if (raced == null) {
                throw new IllegalStateException("Identity subject creation did not produce a mapping.");
            }
            ensureActive(raced);
            return raced;
        }

        audit(learnerId, "IDENTITY_SUBJECT_LINKED", Map.of("actorType", actorType.value));
        recordConsentInternal(
                learnerId,
                ConsentPurpose.REQUIRED_SERVICE,
                REQUIRED_SERVICE_POLICY,
                true,
                now);
        return new LearnerContext(learnerId, actorType, LearnerState.ACTIVE);
    }

    @Transactional
    public LearnerContext resolveForPrivacyStatus(Jwt jwt) {
        String issuer = jwt.getIssuer() == null ? null : jwt.getIssuer().toString();
        String subject = jwt.getSubject();
        if (issuer == null || issuer.isBlank() || subject == null || subject.isBlank()) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "INVALID_IDENTITY_TOKEN",
                    "The access token must contain a valid issuer and subject.");
        }

        LearnerContext learner = findBySubjectHash(hash(issuer + "\0" + subject));
        if (learner == null) {
            return resolve(jwt);
        }
        if (learner.state() == LearnerState.ACTIVE) {
            touch(learner.learnerId());
            return learner;
        }
        if (learner.state() == LearnerState.DELETION_PENDING) {
            return learner;
        }
        ensureActive(learner);
        return learner;
    }

    @Transactional
    public LearnerContext requireLearningAccess(Jwt jwt) {
        LearnerContext learner = resolve(jwt);
        if (learner.actorType() == ActorType.ACCOUNT && profile(learner).ageBand() == null) {
            throw new ApiException(
                    HttpStatus.PRECONDITION_REQUIRED,
                    "ONBOARDING_REQUIRED",
                    "Complete the age-band and language profile before synchronizing account learning data.");
        }
        return learner;
    }

    @Transactional(readOnly = true)
    public LearnerProfile profile(LearnerContext learner) {
        return jdbc.sql("""
                        select ui_locale, source_language, target_language, active_course_id, age_band,
                               learning_goal, preferences::text, updated_at
                        from learner_profiles
                        where learner_id = :learnerId
                        """)
                .param("learnerId", learner.learnerId())
                .query((rs, rowNum) -> new LearnerProfile(
                        learner.learnerId(),
                        learner.actorType(),
                        rs.getString("ui_locale"),
                        rs.getString("source_language"),
                        rs.getString("target_language"),
                        rs.getString("active_course_id"),
                        AgeBand.fromDatabase(rs.getString("age_band")),
                        rs.getString("learning_goal"),
                        readMap(rs.getString("preferences")),
                        rs.getTimestamp("updated_at").toInstant()))
                .single();
    }

    @Transactional
    public LearnerProfile updateProfile(LearnerContext learner, ProfileUpdate update) {
        if (learner.actorType() == ActorType.ACCOUNT && update.ageBand() == AgeBand.UNDER_16) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "GUARDIAN_CONSENT_REQUIRED",
                    "An under-16 account cannot synchronize data until guardian consent is available.");
        }
        validateLearningContext(update);
        Instant now = clock.instant();
        jdbc.sql("""
                        update learner_profiles
                        set ui_locale = :uiLocale,
                            source_language = :sourceLanguage,
                            target_language = :targetLanguage,
                            active_course_id = :activeCourseId,
                            age_band = :ageBand,
                            learning_goal = :learningGoal,
                            preferences = cast(:preferences as jsonb),
                            updated_at = :now
                        where learner_id = :learnerId
                        """)
                .param("uiLocale", update.uiLocale())
                .param("sourceLanguage", update.sourceLanguage())
                .param("targetLanguage", update.targetLanguage())
                .param("activeCourseId", update.activeCourseId())
                .param("ageBand", update.ageBand().value)
                .param("learningGoal", update.learningGoal())
                .param("preferences", writeJson(update.preferences()))
                .param("now", Timestamp.from(now))
                .param("learnerId", learner.learnerId())
                .update();
        audit(
                learner.learnerId(),
                "PROFILE_UPDATED",
                Map.of(
                        "ageBand", update.ageBand().value,
                        "sourceLanguage", update.sourceLanguage(),
                        "targetLanguage", update.targetLanguage(),
                        "activeCourseId", update.activeCourseId()));
        return profile(learner);
    }

    private void validateLearningContext(ProfileUpdate update) {
        if (update.sourceLanguage().equalsIgnoreCase(update.targetLanguage())) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "INVALID_LANGUAGE_PAIR",
                    "Source and target language must be different.");
        }
        long enabledLanguages = jdbc.sql("""
                        select count(*)
                        from learning_languages
                        where enabled = true
                          and language_tag in (:sourceLanguage, :targetLanguage)
                        """)
                .param("sourceLanguage", update.sourceLanguage())
                .param("targetLanguage", update.targetLanguage())
                .query(Long.class)
                .single();
        if (enabledLanguages != 2) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "UNSUPPORTED_LANGUAGE_PAIR",
                    "Source and target language must exist in the enabled language catalog.");
        }
        boolean courseMatches = jdbc.sql("""
                        select exists (
                            select 1
                            from courses
                            where id = :activeCourseId
                              and source_language = :sourceLanguage
                              and target_language = :targetLanguage
                              and published = true
                        )
                        """)
                .param("activeCourseId", update.activeCourseId())
                .param("sourceLanguage", update.sourceLanguage())
                .param("targetLanguage", update.targetLanguage())
                .query(Boolean.class)
                .single();
        if (!courseMatches) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ACTIVE_COURSE_MISMATCH",
                    "The active course must be published for the selected language pair.");
        }
    }

    @Transactional(readOnly = true)
    public List<ConsentRecord> consents(LearnerContext learner) {
        return jdbc.sql("""
                        select distinct on (purpose)
                               purpose, policy_version, granted, recorded_at
                        from consent_records
                        where learner_id = :learnerId
                        order by purpose, recorded_at desc, id desc
                        """)
                .param("learnerId", learner.learnerId())
                .query((rs, rowNum) -> new ConsentRecord(
                        ConsentPurpose.fromValue(rs.getString("purpose")),
                        rs.getString("policy_version"),
                        rs.getBoolean("granted"),
                        rs.getTimestamp("recorded_at").toInstant()))
                .list();
    }

    @Transactional
    public ConsentRecord recordConsent(
            LearnerContext learner,
            ConsentPurpose purpose,
            String policyVersion,
            boolean granted) {
        if (purpose == ConsentPurpose.REQUIRED_SERVICE && !granted) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "REQUIRED_SERVICE_CANNOT_BE_WITHDRAWN",
                    "Required service processing cannot be withdrawn while the learner remains active.");
        }
        Instant now = clock.instant();
        recordConsentInternal(learner.learnerId(), purpose, policyVersion, granted, now);
        audit(
                learner.learnerId(),
                "CONSENT_RECORDED",
                Map.of("purpose", purpose.value, "granted", granted, "policyVersion", policyVersion));
        return new ConsentRecord(purpose, policyVersion, granted, now);
    }

    @Transactional
    public MergeTicket createMergeTicket(LearnerContext learner) {
        if (learner.actorType() != ActorType.GUEST) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "GUEST_REQUIRED",
                    "Only a guest learner can create a merge ticket.");
        }
        Instant now = clock.instant();
        UUID ticketId = UUID.randomUUID();
        String secret = UUID.randomUUID().toString() + UUID.randomUUID();
        String token = ticketId + "." + secret;
        Instant expiresAt = now.plus(15, ChronoUnit.MINUTES);
        jdbc.sql("""
                        insert into guest_merge_tickets (
                            id, guest_learner_id, secret_hash, expires_at
                        ) values (
                            :id, :learnerId, :secretHash, :expiresAt
                        )
                        """)
                .param("id", ticketId)
                .param("learnerId", learner.learnerId())
                .param("secretHash", hash(token))
                .param("expiresAt", Timestamp.from(expiresAt))
                .update();
        audit(learner.learnerId(), "GUEST_MERGE_TICKET_CREATED", Map.of("ticketId", ticketId.toString()));
        return new MergeTicket(token, expiresAt);
    }

    @Transactional
    public MergeResult mergeGuest(
            LearnerContext account,
            UUID idempotencyKey,
            String mergeTicket) {
        if (account.actorType() != ActorType.ACCOUNT) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "ACCOUNT_REQUIRED",
                    "Authenticate with an account before merging guest progress.");
        }
        String requestHash = hash(mergeTicket);
        MergeResult existing = findMerge(idempotencyKey, account.learnerId(), requestHash);
        if (existing != null) {
            return existing;
        }

        UUID ticketId = parseTicketId(mergeTicket);
        TicketRow ticket = jdbc.sql("""
                        select guest_learner_id, expires_at, consumed_at, secret_hash
                        from guest_merge_tickets
                        where id = :ticketId
                        for update
                        """)
                .param("ticketId", ticketId)
                .query((rs, rowNum) -> new TicketRow(
                        rs.getObject("guest_learner_id", UUID.class),
                        rs.getTimestamp("expires_at").toInstant(),
                        rs.getTimestamp("consumed_at") == null
                                ? null
                                : rs.getTimestamp("consumed_at").toInstant(),
                        rs.getString("secret_hash")))
                .optional()
                .orElseThrow(() -> invalidMergeTicket());
        Instant now = clock.instant();
        if (!MessageDigest.isEqual(
                        ticket.secretHash().getBytes(StandardCharsets.US_ASCII),
                        hash(mergeTicket).getBytes(StandardCharsets.US_ASCII))
                || ticket.consumedAt() != null
                || !ticket.expiresAt().isAfter(now)) {
            throw invalidMergeTicket();
        }
        if (ticket.guestLearnerId().equals(account.learnerId())) {
            throw invalidMergeTicket();
        }

        LearnerState guestState = lockLearner(ticket.guestLearnerId());
        if (guestState != LearnerState.ACTIVE) {
            throw invalidMergeTicket();
        }
        if (hasMergedPair(account.learnerId(), ticket.guestLearnerId())) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "GUEST_ALREADY_MERGED",
                    "This guest has already been merged into the account.");
        }

        events.publishEvent(new GuestAccountMerged(ticket.guestLearnerId(), account.learnerId()));
        jdbc.sql("""
                        update learners
                        set state = 'merged', merged_into = :accountLearnerId, updated_at = :now
                        where id = :guestLearnerId
                        """)
                .param("accountLearnerId", account.learnerId())
                .param("guestLearnerId", ticket.guestLearnerId())
                .param("now", Timestamp.from(now))
                .update();
        jdbc.sql("""
                        update guest_merge_tickets
                        set consumed_at = :now
                        where id = :ticketId
                        """)
                .param("now", Timestamp.from(now))
                .param("ticketId", ticketId)
                .update();
        jdbc.sql("""
                        insert into guest_merge_requests (
                            idempotency_key, account_learner_id, guest_learner_id,
                            ticket_id, request_hash, merged_at
                        ) values (
                            :idempotencyKey, :accountLearnerId, :guestLearnerId,
                            :ticketId, :requestHash, :mergedAt
                        )
                        """)
                .param("idempotencyKey", idempotencyKey)
                .param("accountLearnerId", account.learnerId())
                .param("guestLearnerId", ticket.guestLearnerId())
                .param("ticketId", ticketId)
                .param("requestHash", requestHash)
                .param("mergedAt", Timestamp.from(now))
                .update();
        audit(account.learnerId(), "GUEST_MERGED", Map.of("guestLearnerId", ticket.guestLearnerId().toString()));
        audit(ticket.guestLearnerId(), "GUEST_MERGED_INTO_ACCOUNT", Map.of());
        return new MergeResult(ticket.guestLearnerId(), account.learnerId(), now);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> exportIdentityData(UUID learnerId) {
        LearnerContext learner = findByLearnerId(learnerId);
        LearnerProfile profile = profile(learner);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("learnerId", learnerId.toString());
        result.put("state", learner.state().value);
        result.put("actorType", learner.actorType().value);
        result.put("profile", profile);
        result.put("consents", consents(learner));
        return result;
    }

    @Transactional
    public void markDeletionPending(UUID learnerId) {
        int updated = jdbc.sql("""
                        update learners
                        set state = 'deletion_pending', updated_at = :now
                        where id = :learnerId and state = 'active'
                        """)
                .param("now", Timestamp.from(clock.instant()))
                .param("learnerId", learnerId)
                .update();
        if (updated == 0) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "ACCOUNT_NOT_ACTIVE",
                    "The learner account is not active.");
        }
        audit(learnerId, "ACCOUNT_DELETION_REQUESTED", Map.of());
    }

    @Transactional
    public void completeDeletion(UUID learnerId) {
        Instant now = clock.instant();
        jdbc.sql("""
                        update learner_profiles
                        set ui_locale = null,
                            source_language = null,
                            target_language = null,
                            active_course_id = null,
                            age_band = null,
                            learning_goal = null,
                            preferences = '{}'::jsonb,
                            updated_at = :now
                        where learner_id = :learnerId
                        """)
                .param("now", Timestamp.from(now))
                .param("learnerId", learnerId)
                .update();
        jdbc.sql("""
                        update learners
                        set state = 'deleted', updated_at = :now
                        where id = :learnerId and state = 'deletion_pending'
                        """)
                .param("now", Timestamp.from(now))
                .param("learnerId", learnerId)
                .update();
        audit(learnerId, "ACCOUNT_DELETION_COMPLETED", Map.of());
    }

    @Transactional
    public void recordAudit(UUID learnerId, String eventType, Map<String, Object> metadata) {
        audit(learnerId, eventType, metadata);
    }

    private LearnerContext findBySubjectHash(String subjectHash) {
        return jdbc.sql("""
                        select s.learner_id, s.actor_type, l.state
                        from identity_subjects s
                        join learners l on l.id = s.learner_id
                        where s.subject_hash = :subjectHash
                        """)
                .param("subjectHash", subjectHash)
                .query((rs, rowNum) -> new LearnerContext(
                        rs.getObject("learner_id", UUID.class),
                        ActorType.fromClaim(rs.getString("actor_type")),
                        LearnerState.fromValue(rs.getString("state"))))
                .optional()
                .orElse(null);
    }

    private LearnerContext findByLearnerId(UUID learnerId) {
        return jdbc.sql("""
                        select l.id, l.state, s.actor_type
                        from learners l
                        join identity_subjects s on s.learner_id = l.id
                        where l.id = :learnerId
                        order by case when s.actor_type = 'account' then 0 else 1 end
                        limit 1
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new LearnerContext(
                        rs.getObject("id", UUID.class),
                        ActorType.fromClaim(rs.getString("actor_type")),
                        LearnerState.fromValue(rs.getString("state"))))
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "LEARNER_NOT_FOUND", "The learner was not found."));
    }

    private void ensureActive(LearnerContext learner) {
        if (learner.state() != LearnerState.ACTIVE) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "LEARNER_NOT_ACTIVE",
                    "The learner identity is no longer active.");
        }
    }

    private void touch(UUID learnerId) {
        jdbc.sql("update learners set last_activity_at = :now where id = :learnerId")
                .param("now", Timestamp.from(clock.instant()))
                .param("learnerId", learnerId)
                .update();
    }

    private void recordConsentInternal(
            UUID learnerId,
            ConsentPurpose purpose,
            String policyVersion,
            boolean granted,
            Instant recordedAt) {
        jdbc.sql("""
                        insert into consent_records (
                            id, learner_id, purpose, policy_version, granted, recorded_at
                        ) values (
                            :id, :learnerId, :purpose, :policyVersion, :granted, :recordedAt
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("learnerId", learnerId)
                .param("purpose", purpose.value)
                .param("policyVersion", policyVersion)
                .param("granted", granted)
                .param("recordedAt", Timestamp.from(recordedAt))
                .update();
    }

    private void audit(UUID learnerId, String eventType, Map<String, Object> metadata) {
        jdbc.sql("""
                        insert into identity_audit_events (
                            id, learner_id, event_type, event_at, metadata
                        ) values (
                            :id, :learnerId, :eventType, :eventAt, cast(:metadata as jsonb)
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("learnerId", learnerId)
                .param("eventType", eventType)
                .param("eventAt", Timestamp.from(clock.instant()))
                .param("metadata", writeJson(metadata))
                .update();
    }

    private LearnerState lockLearner(UUID learnerId) {
        return jdbc.sql("select state from learners where id = :learnerId for update")
                .param("learnerId", learnerId)
                .query(String.class)
                .optional()
                .map(LearnerState::fromValue)
                .orElseThrow(this::invalidMergeTicket);
    }

    private boolean hasMergedPair(UUID accountLearnerId, UUID guestLearnerId) {
        return jdbc.sql("""
                        select exists(
                            select 1
                            from guest_merge_requests
                            where account_learner_id = :accountLearnerId
                              and guest_learner_id = :guestLearnerId
                        )
                        """)
                .param("accountLearnerId", accountLearnerId)
                .param("guestLearnerId", guestLearnerId)
                .query(Boolean.class)
                .single();
    }

    private MergeResult findMerge(UUID idempotencyKey, UUID accountLearnerId, String requestHash) {
        return jdbc.sql("""
                        select account_learner_id, guest_learner_id, request_hash, merged_at
                        from guest_merge_requests
                        where idempotency_key = :idempotencyKey
                        """)
                .param("idempotencyKey", idempotencyKey)
                .query((rs, rowNum) -> {
                    UUID storedAccount = rs.getObject("account_learner_id", UUID.class);
                    String storedHash = rs.getString("request_hash");
                    if (!storedAccount.equals(accountLearnerId) || !storedHash.equals(requestHash)) {
                        throw new ApiException(
                                HttpStatus.CONFLICT,
                                "IDEMPOTENCY_CONFLICT",
                                "The idempotency key was reused with a different merge request.");
                    }
                    return new MergeResult(
                            rs.getObject("guest_learner_id", UUID.class),
                            storedAccount,
                            rs.getTimestamp("merged_at").toInstant());
                })
                .optional()
                .orElse(null);
    }

    private UUID parseTicketId(String mergeTicket) {
        try {
            int separator = mergeTicket.indexOf('.');
            if (separator <= 0) {
                throw invalidMergeTicket();
            }
            return UUID.fromString(mergeTicket.substring(0, separator));
        } catch (IllegalArgumentException exception) {
            throw invalidMergeTicket();
        }
    }

    private ApiException invalidMergeTicket() {
        return new ApiException(
                HttpStatus.UNPROCESSABLE_CONTENT,
                "INVALID_MERGE_TICKET",
                "The guest merge ticket is invalid or expired.");
    }

    private String hash(String value) {
        try {
            return HexFormat.of()
                    .formatHex(MessageDigest.getInstance("SHA-256")
                            .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available.", exception);
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize identity data.", exception);
        }
    }

    private Map<String, Object> readMap(String json) {
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored identity data is not valid JSON.", exception);
        }
    }

    public enum ActorType {
        GUEST("guest"),
        ACCOUNT("account");

        private final String value;

        ActorType(String value) {
            this.value = value;
        }

        static ActorType fromClaim(String value) {
            for (ActorType type : values()) {
                if (type.value.equals(value)) {
                    return type;
                }
            }
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "INVALID_ACTOR_TYPE",
                    "The access token actor_type claim is invalid.");
        }
    }

    public enum LearnerState {
        ACTIVE("active"),
        RESTRICTED("restricted"),
        MERGE_PENDING("merge_pending"),
        MERGED("merged"),
        DELETION_PENDING("deletion_pending"),
        DELETED("deleted");

        private final String value;

        LearnerState(String value) {
            this.value = value;
        }

        static LearnerState fromValue(String value) {
            for (LearnerState state : values()) {
                if (state.value.equals(value)) {
                    return state;
                }
            }
            throw new IllegalStateException("Unknown learner state: " + value);
        }
    }

    public enum AgeBand {
        UNDER_16("under_16"),
        AGE_16_17("16_17"),
        ADULT("adult");

        private final String value;

        AgeBand(String value) {
            this.value = value;
        }

        public String value() {
            return value;
        }

        static AgeBand fromDatabase(String value) {
            if (value == null) {
                return null;
            }
            for (AgeBand ageBand : values()) {
                if (ageBand.value.equals(value)) {
                    return ageBand;
                }
            }
            throw new IllegalStateException("Unknown age band: " + value);
        }

        public static AgeBand fromApi(String value) {
            return fromDatabase(value);
        }
    }

    public enum ConsentPurpose {
        REQUIRED_SERVICE("required_service"),
        OPERATIONAL_TELEMETRY("operational_telemetry"),
        MARKETING_NOTIFICATIONS("marketing_notifications");

        private final String value;

        ConsentPurpose(String value) {
            this.value = value;
        }

        public String value() {
            return value;
        }

        public static ConsentPurpose fromValue(String value) {
            for (ConsentPurpose purpose : values()) {
                if (purpose.value.equals(value)) {
                    return purpose;
                }
            }
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "INVALID_CONSENT_PURPOSE",
                    "The consent purpose is invalid.");
        }
    }

    public record LearnerContext(UUID learnerId, ActorType actorType, LearnerState state) {}

    public record LearnerProfile(
            UUID learnerId,
            ActorType actorType,
            String uiLocale,
            String sourceLanguage,
            String targetLanguage,
            String activeCourseId,
            AgeBand ageBand,
            String learningGoal,
            Map<String, Object> preferences,
            Instant updatedAt) {}

    public record ProfileUpdate(
            String uiLocale,
            String sourceLanguage,
            String targetLanguage,
            String activeCourseId,
            AgeBand ageBand,
            String learningGoal,
            Map<String, Object> preferences) {}

    public record ConsentRecord(
            ConsentPurpose purpose,
            String policyVersion,
            boolean granted,
            Instant recordedAt) {}

    public record MergeTicket(String mergeTicket, Instant expiresAt) {}

    public record MergeResult(UUID guestLearnerId, UUID accountLearnerId, Instant mergedAt) {}

    private record TicketRow(
            UUID guestLearnerId,
            Instant expiresAt,
            Instant consumedAt,
            String secretHash) {}
}

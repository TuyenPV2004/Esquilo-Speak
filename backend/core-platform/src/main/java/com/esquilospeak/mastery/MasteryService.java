package com.esquilospeak.mastery;

import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.identityprofile.GuestAccountMerged;
import com.esquilospeak.learning.AttemptAccepted;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
@Order(10)
public class MasteryService implements AccountDataParticipant {

    public static final int MODEL_VERSION = 1;
    private static final TypeReference<Map<String, String>> LOCALIZED_TEXT = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ApplicationEventPublisher events;
    private final Clock clock;
    private final ObjectMapper objectMapper;

    public MasteryService(
            JdbcClient jdbc,
            ApplicationEventPublisher events,
            Clock clock,
            ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.events = events;
        this.clock = clock;
        this.objectMapper = objectMapper;
    }

    @EventListener
    @Transactional
    public void recordEvidence(AttemptAccepted event) {
        for (String conceptId : event.conceptIds()) {
            int inserted = jdbc.sql("""
                            insert into mastery_evidence (
                                id, learner_id, attempt_id, concept_id, correct,
                                evidence_weight, model_version, occurred_at
                            ) values (
                                :id, :learnerId, :attemptId, :conceptId, :correct,
                                1.0, :modelVersion, :occurredAt
                            )
                            on conflict (attempt_id, concept_id) do nothing
                            """)
                    .param("id", UUID.randomUUID())
                    .param("learnerId", event.learnerId())
                    .param("attemptId", event.attemptId())
                    .param("conceptId", conceptId)
                    .param("correct", event.correct())
                    .param("modelVersion", MODEL_VERSION)
                    .param("occurredAt", Timestamp.from(event.acceptedAt()))
                    .update();
            if (inserted == 1) {
                recompute(event.learnerId(), conceptId, event.attemptId(), event.correct());
            }
        }
    }

    public List<MasteryState> states(String learnerId) {
        return jdbc.sql("""
                        select state.concept_id,
                               coalesce(concept.default_locale, 'und') as default_locale,
                               coalesce(concept.title, jsonb_build_object('und', state.concept_id))::text as title,
                               state.model_version, state.score,
                               state.correct_evidence_count, state.evidence_count,
                               state.last_evidence_at, state.explanation::text
                        from mastery_states state
                        left join learning_concepts concept on concept.id = state.concept_id
                        where state.learner_id = :learnerId
                        order by state.concept_id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new MasteryState(
                        rs.getString("concept_id"),
                        rs.getString("default_locale"),
                        readLocalizedText(rs.getString("title")),
                        rs.getInt("model_version"),
                        rs.getDouble("score"),
                        rs.getInt("correct_evidence_count"),
                        rs.getInt("evidence_count"),
                        rs.getTimestamp("last_evidence_at").toInstant(),
                        Map.of(
                                "method", "weighted-correct-ratio",
                                "summary",
                                rs.getInt("correct_evidence_count")
                                        + "/"
                                        + rs.getInt("evidence_count")
                                        + " accepted evidence items were correct.")))
                .list();
    }

    private Map<String, String> readLocalizedText(String value) {
        try {
            return objectMapper.readValue(value, LOCALIZED_TEXT);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored localized concept text is invalid.", exception);
        }
    }

    private void recompute(
            String learnerId, String conceptId, UUID attemptId, boolean latestCorrect) {
        EvidenceSummary summary = jdbc.sql("""
                        select count(*) as evidence_count,
                               count(*) filter (where correct) as correct_count,
                               max(occurred_at) as last_evidence_at
                        from mastery_evidence
                        where learner_id = :learnerId and concept_id = :conceptId
                        """)
                .param("learnerId", learnerId)
                .param("conceptId", conceptId)
                .query((rs, rowNum) -> new EvidenceSummary(
                        rs.getInt("evidence_count"),
                        rs.getInt("correct_count"),
                        rs.getTimestamp("last_evidence_at").toInstant()))
                .single();
        double score = (double) summary.correctCount() / summary.evidenceCount();
        Instant updatedAt = clock.instant();
        String explanation = """
                {"method":"weighted-correct-ratio","modelVersion":%d,"correctEvidenceCount":%d,"evidenceCount":%d}
                """.formatted(MODEL_VERSION, summary.correctCount(), summary.evidenceCount());
        jdbc.sql("""
                        insert into mastery_states (
                            learner_id, concept_id, model_version, score,
                            correct_evidence_count, evidence_count, last_evidence_at,
                            explanation, updated_at
                        ) values (
                            :learnerId, :conceptId, :modelVersion, :score,
                            :correctCount, :evidenceCount, :lastEvidenceAt,
                            cast(:explanation as jsonb), :updatedAt
                        )
                        on conflict (learner_id, concept_id) do update
                        set model_version = excluded.model_version,
                            score = excluded.score,
                            correct_evidence_count = excluded.correct_evidence_count,
                            evidence_count = excluded.evidence_count,
                            last_evidence_at = excluded.last_evidence_at,
                            explanation = excluded.explanation,
                            updated_at = excluded.updated_at
                        """)
                .param("learnerId", learnerId)
                .param("conceptId", conceptId)
                .param("modelVersion", MODEL_VERSION)
                .param("score", score)
                .param("correctCount", summary.correctCount())
                .param("evidenceCount", summary.evidenceCount())
                .param("lastEvidenceAt", Timestamp.from(summary.lastEvidenceAt()))
                .param("explanation", explanation)
                .param("updatedAt", Timestamp.from(updatedAt))
                .update();
        events.publishEvent(new MasteryUpdated(
                learnerId,
                attemptId,
                conceptId,
                MODEL_VERSION,
                score,
                summary.correctCount(),
                summary.evidenceCount(),
                latestCorrect,
                updatedAt));
    }

    @Override
    public String dataDomain() {
        return "mastery";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        return Map.of("states", states(learnerId.toString()));
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from mastery_states where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
        jdbc.sql("delete from mastery_evidence where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
    }

    @EventListener
    @Order(Ordered.HIGHEST_PRECEDENCE)
    @Transactional
    void mergeGuestData(GuestAccountMerged event) {
        String guestId = event.guestLearnerId().toString();
        String accountId = event.accountLearnerId().toString();
        List<String> concepts = jdbc.sql("""
                        select distinct concept_id
                        from mastery_evidence
                        where learner_id in (:guestId, :accountId)
                        """)
                .param("guestId", guestId)
                .param("accountId", accountId)
                .query(String.class)
                .list();
        jdbc.sql("""
                        delete from mastery_evidence guest_evidence
                        using attempts guest_attempt
                        where guest_evidence.attempt_id = guest_attempt.id
                          and guest_evidence.learner_id = :guestId
                          and guest_attempt.learner_id = :guestId
                          and exists (
                              select 1
                              from attempts account_attempt
                              where account_attempt.learner_id = :accountId
                                and account_attempt.request_hash = guest_attempt.request_hash
                                and (
                                    account_attempt.client_attempt_id = guest_attempt.client_attempt_id
                                    or account_attempt.idempotency_key = guest_attempt.idempotency_key
                                )
                          )
                        """)
                .param("guestId", guestId)
                .param("accountId", accountId)
                .update();
        jdbc.sql("delete from mastery_states where learner_id = :guestId")
                .param("guestId", guestId)
                .update();
        jdbc.sql("update mastery_evidence set learner_id = :accountId where learner_id = :guestId")
                .param("accountId", accountId)
                .param("guestId", guestId)
                .update();
        for (String concept : concepts) {
            recompute(accountId, concept, UUID.randomUUID(), false);
        }
    }

    public record MasteryState(
            String conceptId,
            String defaultLocale,
            Map<String, String> title,
            int modelVersion,
            double score,
            int correctEvidenceCount,
            int evidenceCount,
            Instant lastEvidenceAt,
            Map<String, Object> explanation) {}

    private record EvidenceSummary(int evidenceCount, int correctCount, Instant lastEvidenceAt) {}
}

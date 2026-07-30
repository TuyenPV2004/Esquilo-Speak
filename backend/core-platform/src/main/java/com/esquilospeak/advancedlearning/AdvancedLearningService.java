package com.esquilospeak.advancedlearning;

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
@Order(200)
public class AdvancedLearningService implements AccountDataParticipant {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final MediaDeliveryPort mediaDelivery;
    private final SpeechProviderPort speechProvider;
    private final WritingConversationProviderPort textProvider;
    private final Clock clock;

    AdvancedLearningService(
            JdbcClient jdbc,
            ObjectMapper objectMapper,
            MediaDeliveryPort mediaDelivery,
            SpeechProviderPort speechProvider,
            WritingConversationProviderPort textProvider,
            Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.mediaDelivery = mediaDelivery;
        this.speechProvider = speechProvider;
        this.textProvider = textProvider;
        this.clock = clock;
    }

    public MediaDeliveryPort.MediaAsset media(String mediaId) {
        return mediaDelivery.load(mediaId);
    }

    @Transactional
    public FeedbackResult assessPronunciation(
            UUID learnerId, UUID clientRequestId, byte[] audio, String expectedText, String locale) {
        if (audio.length > 2_000_000) {
            throw new ApiException(
                    HttpStatus.CONTENT_TOO_LARGE,
                    "AUDIO_TOO_LARGE",
                    "Audio samples must not exceed 2 MB.");
        }
        String requestHash = hash(expectedText + "\0" + locale + "\0" + hash(audio));
        FeedbackResult existing = find(learnerId, clientRequestId, requestHash);
        if (existing != null) {
            return existing;
        }
        SpeechProviderPort.SpeechAssessment assessment =
                speechProvider.assess(audio, expectedText, locale);
        return insert(
                learnerId,
                clientRequestId,
                requestHash,
                "pronunciation",
                null,
                null,
                assessment.transcript(),
                assessment.score(),
                assessment.feedback(),
                assessment.provider());
    }

    @Transactional
    public FeedbackResult assessText(
            UUID learnerId,
            UUID clientRequestId,
            String kind,
            String contentRef,
            String input,
            String locale) {
        if (!kind.equals("writing") && !kind.equals("conversation")) {
            throw new IllegalArgumentException("Unsupported feedback kind.");
        }
        String requestHash = hash(kind + "\0" + contentRef + "\0" + input + "\0" + locale);
        FeedbackResult existing = find(learnerId, clientRequestId, requestHash);
        if (existing != null) {
            return existing;
        }
        WritingConversationProviderPort.TextFeedback feedback =
                textProvider.feedback(kind, input, locale);
        if ("blocked".equals(feedback.safetyState())) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "CONTENT_SAFETY_BLOCKED",
                    "The response cannot be evaluated automatically.");
        }
        return insert(
                learnerId,
                clientRequestId,
                requestHash,
                kind,
                contentRef,
                input,
                null,
                null,
                feedback.feedback(),
                feedback.provider());
    }

    private FeedbackResult insert(
            UUID learnerId,
            UUID clientRequestId,
            String requestHash,
            String kind,
            String contentRef,
            String input,
            String transcript,
            Double score,
            Map<String, Object> feedback,
            String provider) {
        UUID id = UUID.randomUUID();
        Instant createdAt = clock.instant();
        jdbc.sql("""
                        insert into advanced_feedback_results (
                            id, learner_id, client_request_id, request_hash, kind,
                            content_ref, input_text, transcript, score, feedback,
                            provider, created_at
                        ) values (
                            :id, :learnerId, :clientRequestId, :requestHash, :kind,
                            :contentRef, :inputText, :transcript, :score,
                            cast(:feedback as jsonb), :provider, :createdAt
                        )
                        """)
                .param("id", id)
                .param("learnerId", learnerId)
                .param("clientRequestId", clientRequestId)
                .param("requestHash", requestHash)
                .param("kind", kind)
                .param("contentRef", contentRef)
                .param("inputText", input)
                .param("transcript", transcript)
                .param("score", score)
                .param("feedback", writeJson(feedback))
                .param("provider", provider)
                .param("createdAt", Timestamp.from(createdAt))
                .update();
        return new FeedbackResult(id, kind, transcript, score, feedback, provider, createdAt);
    }

    private FeedbackResult find(UUID learnerId, UUID clientRequestId, String requestHash) {
        return jdbc.sql("""
                        select id, request_hash, kind, transcript, score,
                               feedback::text, provider, created_at
                        from advanced_feedback_results
                        where learner_id = :learnerId
                          and client_request_id = :clientRequestId
                        """)
                .param("learnerId", learnerId)
                .param("clientRequestId", clientRequestId)
                .query((rs, rowNum) -> {
                    if (!requestHash.equals(rs.getString("request_hash"))) {
                        throw new ApiException(
                                HttpStatus.CONFLICT,
                                "IDEMPOTENCY_CONFLICT",
                                "The client request identifier was reused with different content.");
                    }
                    Number score = (Number) rs.getObject("score");
                    return new FeedbackResult(
                            rs.getObject("id", UUID.class),
                            rs.getString("kind"),
                            rs.getString("transcript"),
                            score == null ? null : score.doubleValue(),
                            readJson(rs.getString("feedback")),
                            rs.getString("provider"),
                            rs.getTimestamp("created_at").toInstant());
                })
                .optional()
                .orElse(null);
    }

    @Override
    public String dataDomain() {
        return "advancedLearning";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> results = jdbc.sql("""
                        select id, client_request_id, kind, content_ref, input_text,
                               transcript, score, feedback::text, provider, created_at
                        from advanced_feedback_results
                        where learner_id = :learnerId
                        order by created_at, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("id", rs.getObject("id", UUID.class));
                    item.put("clientRequestId", rs.getObject("client_request_id", UUID.class));
                    item.put("kind", rs.getString("kind"));
                    item.put("contentRef", rs.getString("content_ref"));
                    item.put("inputText", rs.getString("input_text"));
                    item.put("transcript", rs.getString("transcript"));
                    item.put("score", rs.getObject("score"));
                    item.put("feedback", readJson(rs.getString("feedback")));
                    item.put("provider", rs.getString("provider"));
                    item.put("createdAt", rs.getTimestamp("created_at").toInstant());
                    return item;
                })
                .list();
        return Map.of("feedbackResults", results, "rawVoiceRetained", false);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from advanced_feedback_results where learner_id = :learnerId")
                .param("learnerId", learnerId)
                .update();
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Unable to encode feedback.", exception);
        }
    }

    private Map<String, Object> readJson(String value) {
        try {
            return objectMapper.readValue(value, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Unable to decode feedback.", exception);
        }
    }

    private static String hash(String value) {
        return hash(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String hash(byte[] value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }

    public record FeedbackResult(
            UUID id,
            String kind,
            String transcript,
            Double score,
            Map<String, Object> feedback,
            String provider,
            Instant createdAt) {}
}

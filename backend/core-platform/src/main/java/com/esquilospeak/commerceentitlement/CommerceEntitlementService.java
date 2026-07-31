package com.esquilospeak.commerceentitlement;

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
@Order(230)
public class CommerceEntitlementService implements AccountDataParticipant {

    private final JdbcClient jdbc;
    private final PurchaseVerificationPort verifier;
    private final Clock clock;

    CommerceEntitlementService(JdbcClient jdbc, PurchaseVerificationPort verifier, Clock clock) {
        this.jdbc = jdbc;
        this.verifier = verifier;
        this.clock = clock;
    }

    @Transactional
    public EntitlementResult verify(
            UUID learnerId, String purchaseToken, String productId, String eventType) {
        PurchaseVerificationPort.Verification verification =
                verifier.verify(purchaseToken, productId, eventType);
        if (!verification.accepted()) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "PURCHASE_NOT_VERIFIED",
                    "The purchase could not be verified.");
        }
        String tokenHash = hash(purchaseToken);
        if ("refund_verified".equals(eventType)) {
            UUID purchaseOwner = jdbc.sql("""
                            select learner_id from purchase_events
                            where purchase_token_hash = :tokenHash
                              and event_type = 'purchase_verified'
                            """)
                    .param("tokenHash", tokenHash)
                    .query(UUID.class)
                    .optional()
                    .orElseThrow(() -> new ApiException(
                            HttpStatus.UNPROCESSABLE_CONTENT,
                            "PURCHASE_NOT_FOUND",
                            "A verified purchase is required before processing a refund."));
            if (!purchaseOwner.equals(learnerId)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "PURCHASE_ALREADY_CLAIMED",
                        "This purchase is linked to another learner.");
            }
        }
        Instant now = clock.instant();
        int inserted = jdbc.sql("""
                        insert into purchase_events (
                            id, learner_id, purchase_token_hash, product_id,
                            event_type, provider_state, occurred_at
                        ) values (
                            :id, :learnerId, :tokenHash, :productId,
                            :eventType, :providerState, :occurredAt
                        ) on conflict (purchase_token_hash, event_type) do nothing
                        """)
                .param("id", UUID.randomUUID())
                .param("learnerId", learnerId)
                .param("tokenHash", tokenHash)
                .param("productId", productId)
                .param("eventType", eventType)
                .param("providerState", verification.state())
                .param("occurredAt", Timestamp.from(now))
                .update();
        if (inserted == 0) {
            UUID owner = jdbc.sql("""
                            select learner_id from purchase_events
                            where purchase_token_hash = :tokenHash and event_type = :eventType
                            """)
                    .param("tokenHash", tokenHash)
                    .param("eventType", eventType)
                    .query(UUID.class)
                    .single();
            if (!owner.equals(learnerId)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "PURCHASE_ALREADY_CLAIMED",
                        "This purchase is already linked to another learner.");
            }
            return entitlement(learnerId, verification.entitlementCode());
        }
        jdbc.sql("""
                        insert into entitlements (
                            learner_id, code, status, valid_until, source, updated_at
                        ) values (
                            :learnerId, :code, :status, :validUntil, :source, :updatedAt
                        ) on conflict (learner_id, code) do update
                        set status = excluded.status,
                            valid_until = excluded.valid_until,
                            source = excluded.source,
                            updated_at = excluded.updated_at
                        """)
                .param("learnerId", learnerId)
                .param("code", verification.entitlementCode())
                .param("status", verification.state())
                .param(
                        "validUntil",
                        verification.validUntil() == null
                                ? null
                                : Timestamp.from(verification.validUntil()))
                .param("source", verification.source())
                .param("updatedAt", Timestamp.from(now))
                .update();
        return new EntitlementResult(
                verification.entitlementCode(),
                verification.state(),
                verification.validUntil(),
                verification.source(),
                now);
    }

    @Transactional(readOnly = true)
    public List<EntitlementResult> entitlements(UUID learnerId) {
        return jdbc.sql("""
                        select code, status, valid_until, source, updated_at
                        from entitlements where learner_id = :learnerId order by code
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new EntitlementResult(
                        rs.getString("code"),
                        rs.getString("status"),
                        rs.getTimestamp("valid_until") == null
                                ? null
                                : rs.getTimestamp("valid_until").toInstant(),
                        rs.getString("source"),
                        rs.getTimestamp("updated_at").toInstant()))
                .list();
    }

    private EntitlementResult entitlement(UUID learnerId, String code) {
        return jdbc.sql("""
                        select code, status, valid_until, source, updated_at
                        from entitlements
                        where learner_id = :learnerId and code = :code
                        """)
                .param("learnerId", learnerId)
                .param("code", code)
                .query((rs, rowNum) -> new EntitlementResult(
                        rs.getString("code"),
                        rs.getString("status"),
                        rs.getTimestamp("valid_until") == null
                                ? null
                                : rs.getTimestamp("valid_until").toInstant(),
                        rs.getString("source"),
                        rs.getTimestamp("updated_at").toInstant()))
                .single();
    }

    @Override
    public String dataDomain() {
        return "commerceEntitlement";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> events = jdbc.sql("""
                        select product_id, event_type, provider_state, occurred_at
                        from purchase_events where learner_id = :learnerId
                        order by occurred_at, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("productId", rs.getString("product_id"));
                    item.put("eventType", rs.getString("event_type"));
                    item.put("providerState", rs.getString("provider_state"));
                    item.put("occurredAt", rs.getTimestamp("occurred_at").toInstant());
                    return item;
                })
                .list();
        return Map.of("entitlements", entitlements(learnerId), "purchaseEvents", events);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from entitlements where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
        jdbc.sql("delete from purchase_events where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }

    public record EntitlementResult(
            String code, String status, Instant validUntil, String source, Instant updatedAt) {}
}

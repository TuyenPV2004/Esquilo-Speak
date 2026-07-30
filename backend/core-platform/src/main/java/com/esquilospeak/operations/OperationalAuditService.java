package com.esquilospeak.operations;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Clock;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

@Service
public class OperationalAuditService {

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public OperationalAuditService(JdbcClient jdbc, ObjectMapper objectMapper, Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(
            String actor,
            String action,
            String outcome,
            String traceId,
            Map<String, Object> metadata) {
        jdbc.sql("""
                        insert into operational_audit_events (
                            id, actor_hash, action, outcome, trace_id, occurred_at, metadata
                        ) values (
                            :id, :actorHash, :action, :outcome, :traceId, :occurredAt,
                            cast(:metadata as jsonb)
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("actorHash", actor == null ? null : hash(actor), Types.CHAR)
                .param("action", action)
                .param("outcome", outcome)
                .param("traceId", traceId)
                .param("occurredAt", Timestamp.from(clock.instant()))
                .param("metadata", writeJson(metadata))
                .update();
    }

    String actorHash(String actor) {
        return hash(actor);
    }

    private String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available.", exception);
        }
    }

    private String writeJson(Map<String, Object> metadata) {
        try {
            return objectMapper.writeValueAsString(metadata);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize operational audit metadata.", exception);
        }
    }
}

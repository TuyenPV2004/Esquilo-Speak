package com.esquilospeak.operations;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
class OperationalRetentionProcessor {

    private static final Duration SECURITY_RETENTION = Duration.ofDays(180);

    private final JdbcClient jdbc;
    private final Clock clock;
    private final boolean enabled;

    OperationalRetentionProcessor(
            JdbcClient jdbc,
            Clock clock,
            @Value("${esquilospeak.operations.retention-enabled:true}") boolean enabled) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.enabled = enabled;
    }

    @Scheduled(cron = "0 15 3 * * *", zone = "UTC")
    void purgeExpiredAuditEvents() {
        if (!enabled) {
            return;
        }
        jdbc.sql("delete from operational_audit_events where occurred_at < :cutoff")
                .param("cutoff", Timestamp.from(clock.instant().minus(SECURITY_RETENTION)))
                .update();
    }
}

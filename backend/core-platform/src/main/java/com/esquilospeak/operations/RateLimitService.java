package com.esquilospeak.operations;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
class RateLimitService {

    private static final Logger LOGGER = LoggerFactory.getLogger(RateLimitService.class);
    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final AtomicLong checks = new AtomicLong();
    private final Clock clock;
    private final OperationalAuditService audit;
    private final MeterRegistry meters;

    RateLimitService(Clock clock, OperationalAuditService audit, MeterRegistry meters) {
        this.clock = clock;
        this.audit = audit;
        this.meters = meters;
    }

    Decision check(
            String actor,
            Policy policy,
            String traceId) {
        Instant now = clock.instant();
        String key = policy.name() + ":" + audit.actorHash(actor);
        Window updated = windows.compute(key, (ignored, current) -> {
            if (current == null || !now.isBefore(current.resetAt())) {
                return new Window(1, now.plus(policy.window()));
            }
            return new Window(current.count() + 1, current.resetAt());
        });
        if ((checks.incrementAndGet() & 1023) == 0) {
            windows.entrySet().removeIf(entry -> !now.isBefore(entry.getValue().resetAt()));
        }
        boolean allowed = updated.count() <= policy.limit();
        if (!allowed) {
            Counter.builder("esquilospeak.rate_limit.rejected")
                    .tag("policy", policy.name())
                    .register(meters)
                    .increment();
            try {
                audit.record(
                        actor,
                        "RATE_LIMIT_EXCEEDED",
                        "rate_limited",
                        traceId,
                        Map.of("policy", policy.name()));
            } catch (RuntimeException exception) {
                LOGGER.atError()
                        .addKeyValue("correlationId", traceId)
                        .addKeyValue("auditAction", "RATE_LIMIT_EXCEEDED")
                        .log("operational_audit_write_failed", exception);
            }
        }
        long retryAfter = Math.max(
                1, Duration.between(now, updated.resetAt()).toSeconds());
        return new Decision(allowed, retryAfter);
    }

    record Policy(String name, int limit, Duration window) {}

    record Decision(boolean allowed, long retryAfterSeconds) {}

    private record Window(int count, Instant resetAt) {}
}

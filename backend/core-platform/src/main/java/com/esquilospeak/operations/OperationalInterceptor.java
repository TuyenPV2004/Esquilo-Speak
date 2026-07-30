package com.esquilospeak.operations;

import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import tools.jackson.databind.ObjectMapper;

@Component
class OperationalInterceptor implements HandlerInterceptor {

    private static final Logger LOGGER = LoggerFactory.getLogger(OperationalInterceptor.class);
    private static final String START_NANOS =
            OperationalInterceptor.class.getName() + ".startNanos";

    private final RateLimitProperties properties;
    private final RateLimitService rateLimits;
    private final OperationalAuditService audit;
    private final MeterRegistry meters;
    private final ObjectMapper objectMapper;

    OperationalInterceptor(
            RateLimitProperties properties,
            RateLimitService rateLimits,
            OperationalAuditService audit,
            MeterRegistry meters,
            ObjectMapper objectMapper) {
        this.properties = properties;
        this.rateLimits = rateLimits;
        this.audit = audit;
        this.meters = meters;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(
            HttpServletRequest request, HttpServletResponse response, Object handler)
            throws IOException {
        request.setAttribute(START_NANOS, System.nanoTime());
        if (!properties.isEnabled()) {
            return true;
        }
        RateLimitService.Policy policy = policy(request);
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (policy == null || authentication == null || !authentication.isAuthenticated()) {
            return true;
        }
        String traceId = traceId(request);
        RateLimitService.Decision decision =
                rateLimits.check(authentication.getName(), policy, traceId);
        response.setHeader("RateLimit-Policy", policy.limit() + ";w=" + policy.window().toSeconds());
        if (decision.allowed()) {
            return true;
        }
        response.setHeader("Retry-After", Long.toString(decision.retryAfterSeconds()));
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        objectMapper.writeValue(
                response.getWriter(),
                Map.of(
                        "type",
                        "https://api.esquilospeak.com/problems/rate_limit_exceeded",
                        "title",
                        "Too Many Requests",
                        "status",
                        HttpStatus.TOO_MANY_REQUESTS.value(),
                        "detail",
                        "The request quota has been exceeded. Retry after the advertised delay.",
                        "code",
                        "RATE_LIMIT_EXCEEDED",
                        "traceId",
                        traceId,
                        "retryable",
                        true));
        logRequestCompletion(request, response);
        return false;
    }

    @Override
    public void afterCompletion(
            HttpServletRequest request,
            HttpServletResponse response,
            Object handler,
            Exception exception) {
        String traceId = logRequestCompletion(request, response);
        String route = routeCategory(request);
        if (request.getRequestURI().startsWith("/api/admin/")
                && !HttpMethod.GET.matches(request.getMethod())) {
            Authentication authentication =
                    SecurityContextHolder.getContext().getAuthentication();
            try {
                audit.record(
                        authentication == null ? null : authentication.getName(),
                        "ADMIN_HTTP_MUTATION",
                        response.getStatus() < 400 ? "allowed" : "failed",
                        traceId,
                        Map.of(
                                "method", request.getMethod(),
                                "route", matchingPattern(request),
                                "status", response.getStatus()));
            } catch (RuntimeException auditException) {
                LOGGER.atError()
                        .addKeyValue("correlationId", traceId)
                        .addKeyValue("auditAction", "ADMIN_HTTP_MUTATION")
                        .log("operational_audit_write_failed", auditException);
            }
        }
        if (response.getStatus() >= 500) {
            meters.counter("esquilospeak.http.server.failures", "route", route)
                    .increment();
        }
    }

    private String logRequestCompletion(
            HttpServletRequest request, HttpServletResponse response) {
        Object started = request.getAttribute(START_NANOS);
        long durationMs = started instanceof Long value
                ? Math.max(0, (System.nanoTime() - value) / 1_000_000)
                : 0;
        String route = routeCategory(request);
        String traceId = traceId(request);
        LOGGER.atInfo()
                .addKeyValue("correlationId", traceId)
                .addKeyValue("httpMethod", request.getMethod())
                .addKeyValue("routeCategory", route)
                .addKeyValue("httpStatus", response.getStatus())
                .addKeyValue("durationMs", durationMs)
                .log("request_completed");
        return traceId;
    }

    private RateLimitService.Policy policy(HttpServletRequest request) {
        String path = request.getRequestURI();
        if (!HttpMethod.POST.matches(request.getMethod())
                && !HttpMethod.PUT.matches(request.getMethod())) {
            return null;
        }
        if ("/api/mobile/v1/attempts".equals(path)) {
            return new RateLimitService.Policy(
                    "attempt-submit",
                    properties.getAttemptsPerMinute(),
                    Duration.ofMinutes(1));
        }
        if ("/api/mobile/v1/sync/push".equals(path)) {
            return new RateLimitService.Policy(
                    "sync-push",
                    properties.getSyncPushPerMinute(),
                    Duration.ofMinutes(1));
        }
        if (path.startsWith("/api/mobile/v1/me/privacy/")) {
            return new RateLimitService.Policy(
                    "privacy-request",
                    properties.getPrivacyPerHour(),
                    Duration.ofHours(1));
        }
        if (path.startsWith("/api/admin/v1/content/")) {
            return new RateLimitService.Policy(
                    "content-admin-write",
                    properties.getAdminWritesPerMinute(),
                    Duration.ofMinutes(1));
        }
        return null;
    }

    private String routeCategory(HttpServletRequest request) {
        String path = request.getRequestURI();
        if (path.startsWith("/api/admin/")) {
            return "content-admin";
        }
        if (path.startsWith("/api/mobile/v1/sync")) {
            return "learning-sync";
        }
        if (path.startsWith("/api/mobile/v1/me")) {
            return "identity-profile";
        }
        if (path.startsWith("/api/mobile/v1")) {
            return "learner-api";
        }
        if (path.startsWith("/actuator") || path.equals("/livez") || path.equals("/readyz")) {
            return "management";
        }
        return "other";
    }

    private String matchingPattern(HttpServletRequest request) {
        Object value = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
        return value == null ? routeCategory(request) : value.toString();
    }

    private String traceId(HttpServletRequest request) {
        Object value = request.getAttribute("com.esquilospeak.CorrelationIdFilter.traceId");
        return value == null ? "unavailable" : value.toString();
    }
}

package com.esquilospeak.operations;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

@Component
public class SecurityFailureHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    private static final Logger LOGGER = LoggerFactory.getLogger(SecurityFailureHandler.class);
    private final OperationalAuditService audit;
    private final ObjectMapper objectMapper;

    public SecurityFailureHandler(OperationalAuditService audit, ObjectMapper objectMapper) {
        this.audit = audit;
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException exception)
            throws IOException {
        write(request, response, null, 401, "UNAUTHORIZED", "Authentication is required.");
    }

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException exception)
            throws IOException {
        Authentication authentication =
                org.springframework.security.core.context.SecurityContextHolder.getContext()
                        .getAuthentication();
        write(
                request,
                response,
                authentication == null ? null : authentication.getName(),
                403,
                "ACCESS_DENIED",
                "The authenticated actor is not allowed to perform this action.");
    }

    private void write(
            HttpServletRequest request,
            HttpServletResponse response,
            String actor,
            int status,
            String code,
            String detail)
            throws IOException {
        String traceId = traceId(request);
        try {
            audit.record(
                    actor,
                    "SECURITY_ACCESS_REJECTED",
                    "denied",
                    traceId,
                    Map.of("status", status, "route", routeCategory(request)));
        } catch (RuntimeException exception) {
            LOGGER.atError()
                    .addKeyValue("correlationId", traceId)
                    .addKeyValue("auditAction", "SECURITY_ACCESS_REJECTED")
                    .log("operational_audit_write_failed", exception);
        }
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.getWriter().write(json(Map.of(
                "type", "https://api.esquilospeak.com/problems/" + code.toLowerCase(),
                "title", status == 401 ? "Unauthorized" : "Forbidden",
                "status", status,
                "detail", detail,
                "code", code,
                "traceId", traceId,
                "retryable", false)));
    }

    private String json(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize the security response.", exception);
        }
    }

    private String traceId(HttpServletRequest request) {
        Object value = request.getAttribute("com.esquilospeak.CorrelationIdFilter.traceId");
        return value == null ? "unavailable" : value.toString();
    }

    private String routeCategory(HttpServletRequest request) {
        String path = request.getRequestURI();
        if (path.startsWith("/api/admin/")) {
            return "content-admin";
        }
        if (path.startsWith("/api/mobile/")) {
            return "mobile";
        }
        if (path.startsWith("/actuator") || path.equals("/livez") || path.equals("/readyz")) {
            return "management";
        }
        return "other";
    }
}

package com.esquilospeak.support;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.operations.OperationalAuditService;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Order(240)
public class SupportService implements AccountDataParticipant {

    private final JdbcClient jdbc;
    private final Clock clock;
    private final OperationalAuditService audit;

    SupportService(JdbcClient jdbc, Clock clock, OperationalAuditService audit) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.audit = audit;
    }

    @Transactional
    public Ticket create(
            UUID learnerId,
            String type,
            String contentRef,
            String locale,
            String description) {
        UUID id = UUID.randomUUID();
        Instant now = clock.instant();
        jdbc.sql("""
                        insert into support_tickets (
                            id, learner_id, ticket_type, content_ref, locale,
                            description, status, created_at, updated_at
                        ) values (
                            :id, :learnerId, :ticketType, :contentRef, :locale,
                            :description, 'open', :createdAt, :updatedAt
                        )
                        """)
                .param("id", id)
                .param("learnerId", learnerId)
                .param("ticketType", type)
                .param("contentRef", contentRef)
                .param("locale", locale)
                .param("description", description)
                .param("createdAt", Timestamp.from(now))
                .param("updatedAt", Timestamp.from(now))
                .update();
        return new Ticket(id, type, contentRef, locale, description, "open", now, now);
    }

    @Transactional(readOnly = true)
    public List<Ticket> list(UUID learnerId) {
        return jdbc.sql("""
                        select id, ticket_type, content_ref, locale, description,
                               status, created_at, updated_at
                        from support_tickets where learner_id = :learnerId
                        order by created_at desc, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new Ticket(
                        rs.getObject("id", UUID.class),
                        rs.getString("ticket_type"),
                        rs.getString("content_ref"),
                        rs.getString("locale"),
                        rs.getString("description"),
                        rs.getString("status"),
                        rs.getTimestamp("created_at").toInstant(),
                        rs.getTimestamp("updated_at").toInstant()))
                .list();
    }

    @Transactional
    public Ticket updateStatus(UUID ticketId, String status) {
        Instant now = clock.instant();
        int updated = jdbc.sql("""
                        update support_tickets set status = :status, updated_at = :updatedAt
                        where id = :id
                        """)
                .param("status", status)
                .param("updatedAt", Timestamp.from(now))
                .param("id", ticketId)
                .update();
        if (updated == 0) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND, "SUPPORT_TICKET_NOT_FOUND", "Support ticket not found.");
        }
        return jdbc.sql("""
                        select id, ticket_type, content_ref, locale, description,
                               status, created_at, updated_at
                        from support_tickets where id = :id
                        """)
                .param("id", ticketId)
                .query((rs, rowNum) -> new Ticket(
                        rs.getObject("id", UUID.class),
                        rs.getString("ticket_type"),
                        rs.getString("content_ref"),
                        rs.getString("locale"),
                        rs.getString("description"),
                        rs.getString("status"),
                        rs.getTimestamp("created_at").toInstant(),
                        rs.getTimestamp("updated_at").toInstant()))
                .single();
    }

    @Transactional(readOnly = true)
    public List<OperationalTicket> listOperational() {
        return jdbc.sql("""
                        select id, ticket_type, content_ref, locale, description,
                               status, severity, owner_ref, action_plan,
                               release_decision, resolution_summary, closed_loop_at,
                               created_at, updated_at
                        from support_tickets
                        order by
                          case severity when 'P0' then 0 when 'P1' then 1 else 2 end,
                          created_at, id
                        """)
                .query((rs, rowNum) -> operationalTicket(rs))
                .list();
    }

    @Transactional
    public OperationalTicket triage(
            UUID ticketId,
            String actor,
            String status,
            String severity,
            String ownerRef,
            String actionPlan,
            String releaseDecision,
            String resolutionSummary,
            boolean closedLoopConfirmed) {
        validateTriage(status, severity, releaseDecision, resolutionSummary, closedLoopConfirmed);
        Instant now = clock.instant();
        Instant closedLoopAt = closedLoopConfirmed ? now : null;
        int updated = jdbc.sql("""
                        update support_tickets set
                          status = :status,
                          severity = :severity,
                          owner_ref = :ownerRef,
                          action_plan = :actionPlan,
                          release_decision = :releaseDecision,
                          resolution_summary = :resolutionSummary,
                          closed_loop_at = :closedLoopAt,
                          updated_at = :updatedAt
                        where id = :id
                        """)
                .param("status", status)
                .param("severity", severity)
                .param("ownerRef", ownerRef)
                .param("actionPlan", actionPlan)
                .param("releaseDecision", releaseDecision)
                .param("resolutionSummary", resolutionSummary, Types.VARCHAR)
                .param(
                        "closedLoopAt",
                        closedLoopAt == null ? null : Timestamp.from(closedLoopAt),
                        Types.TIMESTAMP)
                .param("updatedAt", Timestamp.from(now))
                .param("id", ticketId)
                .update();
        if (updated == 0) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND, "SUPPORT_TICKET_NOT_FOUND", "Support ticket not found.");
        }
        jdbc.sql("""
                        insert into support_ticket_triage_events (
                          id, ticket_id, actor_hash, status, severity, owner_ref,
                          action_plan, release_decision, resolution_summary,
                          closed_loop_confirmed, occurred_at
                        ) values (
                          :id, :ticketId, :actorHash, :status, :severity, :ownerRef,
                          :actionPlan, :releaseDecision, :resolutionSummary,
                          :closedLoopConfirmed, :occurredAt
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("ticketId", ticketId)
                .param("actorHash", audit.actorHash(actor))
                .param("status", status)
                .param("severity", severity)
                .param("ownerRef", ownerRef)
                .param("actionPlan", actionPlan)
                .param("releaseDecision", releaseDecision)
                .param("resolutionSummary", resolutionSummary, Types.VARCHAR)
                .param("closedLoopConfirmed", closedLoopConfirmed)
                .param("occurredAt", Timestamp.from(now))
                .update();
        return jdbc.sql("""
                        select id, ticket_type, content_ref, locale, description,
                               status, severity, owner_ref, action_plan,
                               release_decision, resolution_summary, closed_loop_at,
                               created_at, updated_at
                        from support_tickets where id = :id
                        """)
                .param("id", ticketId)
                .query((rs, rowNum) -> operationalTicket(rs))
                .single();
    }

    private void validateTriage(
            String status,
            String severity,
            String releaseDecision,
            String resolutionSummary,
            boolean closedLoopConfirmed) {
        if ("P0".equals(severity) && "accept_with_plan".equals(releaseDecision)) {
            throw invalidTriage("P0 findings cannot be accepted for release with a plan.");
        }
        if ("triaged".equals(status)
                && !("pending".equals(releaseDecision)
                        || "block".equals(releaseDecision)
                        || "accept_with_plan".equals(releaseDecision))) {
            throw invalidTriage("Triaged findings require a pending, block or accept-with-plan decision.");
        }
        if ("resolved".equals(status)
                && (!"fixed".equals(releaseDecision)
                        || isBlank(resolutionSummary)
                        || !closedLoopConfirmed)) {
            throw invalidTriage(
                    "Resolved findings require a fixed decision, resolution summary and confirmed tester loop.");
        }
        if ("dismissed".equals(status)
                && (!"not_applicable".equals(releaseDecision)
                        || isBlank(resolutionSummary)
                        || !closedLoopConfirmed)) {
            throw invalidTriage(
                    "Dismissed findings require a not-applicable decision, summary and confirmed tester loop.");
        }
        if ("triaged".equals(status) && closedLoopConfirmed) {
            throw invalidTriage("An unresolved finding cannot have a confirmed tester loop.");
        }
    }

    private ApiException invalidTriage(String detail) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "SUPPORT_TRIAGE_INVALID", detail);
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private OperationalTicket operationalTicket(java.sql.ResultSet rs) throws java.sql.SQLException {
        Timestamp closedLoopAt = rs.getTimestamp("closed_loop_at");
        return new OperationalTicket(
                rs.getObject("id", UUID.class),
                rs.getString("ticket_type"),
                rs.getString("content_ref"),
                rs.getString("locale"),
                rs.getString("description"),
                rs.getString("status"),
                rs.getString("severity"),
                rs.getString("owner_ref"),
                rs.getString("action_plan"),
                rs.getString("release_decision"),
                rs.getString("resolution_summary"),
                closedLoopAt == null ? null : closedLoopAt.toInstant(),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant());
    }

    @Override
    public String dataDomain() {
        return "support";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        return Map.of("tickets", list(learnerId));
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from support_tickets where learner_id = :learnerId")
                .param("learnerId", learnerId)
                .update();
    }

    public record Ticket(
            UUID id,
            String type,
            String contentRef,
            String locale,
            String description,
            String status,
            Instant createdAt,
            Instant updatedAt) {}

    public record OperationalTicket(
            UUID id,
            String type,
            String contentRef,
            String locale,
            String description,
            String status,
            String severity,
            String ownerRef,
            String actionPlan,
            String releaseDecision,
            String resolutionSummary,
            Instant closedLoopAt,
            Instant createdAt,
            Instant updatedAt) {}
}

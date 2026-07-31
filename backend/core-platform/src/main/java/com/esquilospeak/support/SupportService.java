package com.esquilospeak.support;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import java.sql.Timestamp;
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

    SupportService(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
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
}

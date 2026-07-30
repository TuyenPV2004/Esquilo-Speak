package com.esquilospeak.reviewscheduler;

import com.esquilospeak.identityprofile.AccountDataParticipant;
import com.esquilospeak.identityprofile.GuestAccountMerged;
import com.esquilospeak.mastery.MasteryUpdated;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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

@Service
@Order(10)
public class ReviewSchedulerService implements AccountDataParticipant {

    private final JdbcClient jdbc;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public ReviewSchedulerService(
            JdbcClient jdbc, ApplicationEventPublisher events, Clock clock) {
        this.jdbc = jdbc;
        this.events = events;
        this.clock = clock;
    }

    @EventListener
    @Transactional
    public void schedule(MasteryUpdated event) {
        StoredSchedule current = find(event.learnerId(), event.conceptId());
        int repetitions;
        int intervalDays;
        double easeFactor;
        if (!event.latestCorrect()) {
            repetitions = 0;
            intervalDays = 0;
            easeFactor = Math.max(1.30, (current == null ? 2.50 : current.easeFactor()) - 0.20);
        } else {
            repetitions = (current == null ? 0 : current.repetitions()) + 1;
            easeFactor = Math.max(1.30, (current == null ? 2.50 : current.easeFactor()) + 0.10);
            intervalDays = switch (repetitions) {
                case 1 -> 1;
                case 2 -> 3;
                default -> Math.max(
                        1,
                        (int) Math.round(
                                (current == null ? 3 : current.intervalDays()) * easeFactor));
            };
        }
        Instant updatedAt = clock.instant();
        Instant dueAt = updatedAt.plus(intervalDays, ChronoUnit.DAYS);
        String lastResult = event.latestCorrect() ? "correct" : "incorrect";
        jdbc.sql("""
                        insert into review_schedules (
                            learner_id, concept_id, model_version, due_at,
                            interval_days, ease_factor, repetitions, last_result, updated_at
                        ) values (
                            :learnerId, :conceptId, :modelVersion, :dueAt,
                            :intervalDays, :easeFactor, :repetitions, :lastResult, :updatedAt
                        )
                        on conflict (learner_id, concept_id) do update
                        set model_version = excluded.model_version,
                            due_at = excluded.due_at,
                            interval_days = excluded.interval_days,
                            ease_factor = excluded.ease_factor,
                            repetitions = excluded.repetitions,
                            last_result = excluded.last_result,
                            updated_at = excluded.updated_at
                        """)
                .param("learnerId", event.learnerId())
                .param("conceptId", event.conceptId())
                .param("modelVersion", event.modelVersion())
                .param("dueAt", Timestamp.from(dueAt))
                .param("intervalDays", intervalDays)
                .param("easeFactor", easeFactor)
                .param("repetitions", repetitions)
                .param("lastResult", lastResult)
                .param("updatedAt", Timestamp.from(updatedAt))
                .update();
        events.publishEvent(new ReviewScheduled(
                event.learnerId(),
                event.conceptId(),
                event.modelVersion(),
                dueAt,
                intervalDays,
                repetitions,
                lastResult,
                updatedAt));
    }

    public List<ReviewItem> dueQueue(String learnerId, int limit) {
        return jdbc.sql("""
                        select concept_id, model_version, due_at, interval_days,
                               ease_factor, repetitions, last_result
                        from review_schedules
                        where learner_id = :learnerId and due_at <= :now
                        order by due_at, concept_id
                        limit :limit
                        """)
                .param("learnerId", learnerId)
                .param("now", Timestamp.from(clock.instant()))
                .param("limit", limit)
                .query((rs, rowNum) -> new ReviewItem(
                        rs.getString("concept_id"),
                        rs.getInt("model_version"),
                        rs.getTimestamp("due_at").toInstant(),
                        rs.getInt("interval_days"),
                        rs.getDouble("ease_factor"),
                        rs.getInt("repetitions"),
                        rs.getString("last_result")))
                .list();
    }

    private StoredSchedule find(String learnerId, String conceptId) {
        return jdbc.sql("""
                        select interval_days, ease_factor, repetitions
                        from review_schedules
                        where learner_id = :learnerId and concept_id = :conceptId
                        """)
                .param("learnerId", learnerId)
                .param("conceptId", conceptId)
                .query((rs, rowNum) -> new StoredSchedule(
                        rs.getInt("interval_days"),
                        rs.getDouble("ease_factor"),
                        rs.getInt("repetitions")))
                .optional()
                .orElse(null);
    }

    @Override
    public String dataDomain() {
        return "reviewSchedule";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        List<ReviewItem> items = jdbc.sql("""
                        select concept_id, model_version, due_at, interval_days,
                               ease_factor, repetitions, last_result
                        from review_schedules
                        where learner_id = :learnerId
                        order by due_at, concept_id
                        """)
                .param("learnerId", learnerId.toString())
                .query((rs, rowNum) -> new ReviewItem(
                        rs.getString("concept_id"),
                        rs.getInt("model_version"),
                        rs.getTimestamp("due_at").toInstant(),
                        rs.getInt("interval_days"),
                        rs.getDouble("ease_factor"),
                        rs.getInt("repetitions"),
                        rs.getString("last_result")))
                .list();
        return Map.of("items", items);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from review_schedules where learner_id = :learnerId")
                .param("learnerId", learnerId.toString())
                .update();
    }

    @EventListener
    @Order(Ordered.HIGHEST_PRECEDENCE + 30)
    @Transactional
    void mergeGuestData(GuestAccountMerged event) {
        String guestId = event.guestLearnerId().toString();
        String accountId = event.accountLearnerId().toString();
        jdbc.sql("""
                        insert into review_schedules (
                            learner_id, concept_id, model_version, due_at,
                            interval_days, ease_factor, repetitions, last_result, updated_at
                        )
                        select :accountId, concept_id, model_version, due_at,
                               interval_days, ease_factor, repetitions, last_result, updated_at
                        from review_schedules
                        where learner_id = :guestId
                        on conflict (learner_id, concept_id) do update
                        set due_at = least(review_schedules.due_at, excluded.due_at),
                            model_version = greatest(review_schedules.model_version, excluded.model_version),
                            updated_at = greatest(review_schedules.updated_at, excluded.updated_at)
                        """)
                .param("accountId", accountId)
                .param("guestId", guestId)
                .update();
        jdbc.sql("delete from review_schedules where learner_id = :guestId")
                .param("guestId", guestId)
                .update();
    }

    public record ReviewItem(
            String conceptId,
            int modelVersion,
            Instant dueAt,
            int intervalDays,
            double easeFactor,
            int repetitions,
            String lastResult) {}

    private record StoredSchedule(int intervalDays, double easeFactor, int repetitions) {}
}

package com.esquilospeak.engagement;

import com.esquilospeak.identityprofile.AccountDataParticipant;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Order(220)
public class EngagementService implements AccountDataParticipant {

    private final JdbcClient jdbc;
    private final Clock clock;

    EngagementService(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EngagementStatus status(UUID learnerId) {
        Profile profile = jdbc.sql("""
                        select current_streak, longest_streak, xp, last_learning_date
                        from engagement_profiles where learner_id = :learnerId
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new Profile(
                        rs.getInt("current_streak"),
                        rs.getInt("longest_streak"),
                        rs.getInt("xp"),
                        rs.getDate("last_learning_date") == null
                                ? null
                                : rs.getDate("last_learning_date").toLocalDate()))
                .optional()
                .orElse(new Profile(0, 0, 0, null));
        List<Achievement> achievements = jdbc.sql("""
                        select code, earned_at from learner_achievements
                        where learner_id = :learnerId order by earned_at, code
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new Achievement(
                        rs.getString("code"), rs.getTimestamp("earned_at").toInstant()))
                .list();
        NotificationPreference preference = preference(learnerId);
        return new EngagementStatus(
                profile.currentStreak(),
                profile.longestStreak(),
                profile.xp(),
                profile.lastLearningDate(),
                achievements,
                preference);
    }

    @Transactional
    public EngagementStatus recordActivity(
            UUID learnerId, UUID clientEventId, String eventType, int xpAwarded) {
        Instant now = clock.instant();
        LocalDate today = now.atZone(ZoneOffset.UTC).toLocalDate();
        jdbc.sql("""
                        insert into engagement_profiles (
                            learner_id, current_streak, longest_streak, xp, updated_at
                        ) values (:learnerId, 0, 0, 0, :now)
                        on conflict (learner_id) do nothing
                        """)
                .param("learnerId", learnerId)
                .param("now", Timestamp.from(now))
                .update();
        int inserted = jdbc.sql("""
                        insert into engagement_events (
                            id, learner_id, client_event_id, event_type,
                            xp_awarded, occurred_on, created_at
                        ) values (
                            :id, :learnerId, :clientEventId, :eventType,
                            :xpAwarded, :occurredOn, :createdAt
                        ) on conflict (learner_id, client_event_id) do nothing
                        """)
                .param("id", UUID.randomUUID())
                .param("learnerId", learnerId)
                .param("clientEventId", clientEventId)
                .param("eventType", eventType)
                .param("xpAwarded", xpAwarded)
                .param("occurredOn", Date.valueOf(today))
                .param("createdAt", Timestamp.from(now))
                .update();
        if (inserted == 0) {
            return status(learnerId);
        }
        Profile current = jdbc.sql("""
                        select current_streak, longest_streak, xp, last_learning_date
                        from engagement_profiles
                        where learner_id = :learnerId for update
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new Profile(
                        rs.getInt("current_streak"),
                        rs.getInt("longest_streak"),
                        rs.getInt("xp"),
                        rs.getDate("last_learning_date") == null
                                ? null
                                : rs.getDate("last_learning_date").toLocalDate()))
                .single();
        int streak = calculateStreak(current, today);
        int longest = Math.max(current.longestStreak(), streak);
        jdbc.sql("""
                        update engagement_profiles
                        set current_streak = :streak, longest_streak = :longest,
                            xp = xp + :xpAwarded, last_learning_date = :today,
                            updated_at = :now
                        where learner_id = :learnerId
                        """)
                .param("streak", streak)
                .param("longest", longest)
                .param("xpAwarded", xpAwarded)
                .param("today", Date.valueOf(today))
                .param("now", Timestamp.from(now))
                .param("learnerId", learnerId)
                .update();
        award(learnerId, "first-step", now);
        if (streak >= 7) {
            award(learnerId, "seven-day-streak", now);
        }
        return status(learnerId);
    }

    @Transactional
    public NotificationPreference updatePreference(
            UUID learnerId, boolean enabled, LocalTime reminderTime, String locale) {
        Instant now = clock.instant();
        jdbc.sql("""
                        insert into notification_preferences (
                            learner_id, enabled, reminder_time, locale, updated_at
                        ) values (
                            :learnerId, :enabled, :reminderTime, :locale, :updatedAt
                        ) on conflict (learner_id) do update
                        set enabled = excluded.enabled,
                            reminder_time = excluded.reminder_time,
                            locale = excluded.locale,
                            updated_at = excluded.updated_at
                        """)
                .param("learnerId", learnerId)
                .param("enabled", enabled)
                .param("reminderTime", reminderTime == null ? null : Time.valueOf(reminderTime))
                .param("locale", locale)
                .param("updatedAt", Timestamp.from(now))
                .update();
        return new NotificationPreference(enabled, reminderTime, locale, now);
    }

    private int calculateStreak(Profile current, LocalDate today) {
        if (today.equals(current.lastLearningDate())) {
            return current.currentStreak();
        }
        if (current.lastLearningDate() != null
                && today.minusDays(1).equals(current.lastLearningDate())) {
            return current.currentStreak() + 1;
        }
        return 1;
    }

    private void award(UUID learnerId, String code, Instant now) {
        jdbc.sql("""
                        insert into learner_achievements (learner_id, code, earned_at)
                        values (:learnerId, :code, :earnedAt)
                        on conflict (learner_id, code) do nothing
                        """)
                .param("learnerId", learnerId)
                .param("code", code)
                .param("earnedAt", Timestamp.from(now))
                .update();
    }

    private NotificationPreference preference(UUID learnerId) {
        return jdbc.sql("""
                        select enabled, reminder_time, locale, updated_at
                        from notification_preferences where learner_id = :learnerId
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new NotificationPreference(
                        rs.getBoolean("enabled"),
                        rs.getTime("reminder_time") == null
                                ? null
                                : rs.getTime("reminder_time").toLocalTime(),
                        rs.getString("locale"),
                        rs.getTimestamp("updated_at").toInstant()))
                .optional()
                .orElse(new NotificationPreference(false, null, "vi", null));
    }

    @Override
    public String dataDomain() {
        return "engagement";
    }

    @Override
    public Map<String, Object> exportData(UUID learnerId) {
        EngagementStatus current = status(learnerId);
        List<Map<String, Object>> events = jdbc.sql("""
                        select client_event_id, event_type, xp_awarded, occurred_on, created_at
                        from engagement_events where learner_id = :learnerId
                        order by created_at, id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("clientEventId", rs.getObject("client_event_id", UUID.class));
                    item.put("eventType", rs.getString("event_type"));
                    item.put("xpAwarded", rs.getInt("xp_awarded"));
                    item.put("occurredOn", rs.getDate("occurred_on").toLocalDate());
                    item.put("createdAt", rs.getTimestamp("created_at").toInstant());
                    return item;
                })
                .list();
        return Map.of("status", current, "events", events);
    }

    @Override
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from learner_achievements where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
        jdbc.sql("delete from engagement_events where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
        jdbc.sql("delete from notification_preferences where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
        jdbc.sql("delete from engagement_profiles where learner_id = :learnerId")
                .param("learnerId", learnerId).update();
    }

    private record Profile(int currentStreak, int longestStreak, int xp, LocalDate lastLearningDate) {}

    public record Achievement(String code, Instant earnedAt) {}

    public record NotificationPreference(
            boolean enabled, LocalTime reminderTime, String locale, Instant updatedAt) {}

    public record EngagementStatus(
            int currentStreak,
            int longestStreak,
            int xp,
            LocalDate lastLearningDate,
            List<Achievement> achievements,
            NotificationPreference notificationPreference) {}
}

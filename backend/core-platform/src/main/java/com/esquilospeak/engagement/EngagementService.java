package com.esquilospeak.engagement;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
@Order(220)
public class EngagementService implements AccountDataParticipant {

    private static final TypeReference<Map<String, String>> LOCALIZED_TEXT = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final Clock clock;
    private final ObjectMapper objectMapper;

    EngagementService(JdbcClient jdbc, Clock clock, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.objectMapper = objectMapper;
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
                        select achievement.code, achievement.earned_at,
                               policy.title::text, policy.description::text
                        from learner_achievements achievement
                        join engagement_achievement_policies policy
                          on policy.code = achievement.code
                        where achievement.learner_id = :learnerId
                        order by achievement.earned_at, achievement.code
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new Achievement(
                        rs.getString("code"),
                        readLocalizedText(rs.getString("title")),
                        readLocalizedText(rs.getString("description")),
                        rs.getTimestamp("earned_at").toInstant()))
                .list();
        NotificationPreference preference = preference(learnerId);
        DailyLearningPolicy policy = activeDailyLearningPolicy();
        return new EngagementStatus(
                profile.currentStreak(),
                profile.longestStreak(),
                profile.xp(),
                profile.lastLearningDate(),
                achievements,
                preference,
                policy,
                dailyGoal(learnerId, preference.timezone(), policy));
    }

    @Transactional
    public EngagementStatus recordActivity(
            UUID learnerId, UUID clientEventId, String eventType, String evidenceRef) {
        Instant now = clock.instant();
        EventPolicy policy = activePolicy(eventType);
        if (policy.requiresEvidence()) {
            validateEvidence(learnerId, eventType, evidenceRef);
        }
        LocalDate today = now.atZone(zoneId(preference(learnerId).timezone())).toLocalDate();
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
                            xp_awarded, occurred_on, created_at, policy_version, evidence_ref
                        ) values (
                            :id, :learnerId, :clientEventId, :eventType,
                            :xpAwarded, :occurredOn, :createdAt, :policyVersion, :evidenceRef
                        ) on conflict do nothing
                        """)
                .param("id", UUID.randomUUID())
                .param("learnerId", learnerId)
                .param("clientEventId", clientEventId)
                .param("eventType", eventType)
                .param("xpAwarded", policy.xpAwarded())
                .param("occurredOn", Date.valueOf(today))
                .param("createdAt", Timestamp.from(now))
                .param("policyVersion", policy.version())
                .param("evidenceRef", evidenceRef)
                .update();
        if (inserted == 0) {
            return status(learnerId);
        }
        if (!policy.countsTowardStreak()) {
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
                .param("xpAwarded", policy.xpAwarded())
                .param("today", Date.valueOf(today))
                .param("now", Timestamp.from(now))
                .param("learnerId", learnerId)
                .update();
        awardEligible(learnerId, streak, now);
        return status(learnerId);
    }

    @Transactional
    public NotificationPreference updatePreference(
            UUID learnerId, boolean enabled, LocalTime reminderTime, String locale, String timezone) {
        zoneId(timezone);
        DailyLearningPolicy policy = activeDailyLearningPolicy();
        if (enabled && reminderTime == null) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "REMINDER_TIME_REQUIRED",
                    "An enabled reminder requires a delivery time.");
        }
        if (enabled && policy.isQuietTime(reminderTime)) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "REMINDER_IN_QUIET_HOURS",
                    "The reminder time must be outside the active quiet hours.");
        }
        Instant now = clock.instant();
        jdbc.sql("""
                        insert into notification_preferences (
                            learner_id, enabled, reminder_time, locale, timezone, updated_at
                        ) values (
                            :learnerId, :enabled, :reminderTime, :locale, :timezone, :updatedAt
                        ) on conflict (learner_id) do update
                        set enabled = excluded.enabled,
                            reminder_time = excluded.reminder_time,
                            locale = excluded.locale,
                            timezone = excluded.timezone,
                            updated_at = excluded.updated_at
                        """)
                .param("learnerId", learnerId)
                .param("enabled", enabled)
                .param("reminderTime", reminderTime == null ? null : Time.valueOf(reminderTime))
                .param("locale", locale)
                .param("timezone", timezone)
                .param("updatedAt", Timestamp.from(now))
                .update();
        return new NotificationPreference(enabled, reminderTime, locale, timezone, now);
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

    private void awardEligible(UUID learnerId, int streak, Instant now) {
        int activityCount = jdbc.sql("""
                        select count(*) from engagement_events
                        where learner_id = :learnerId and xp_awarded > 0
                        """)
                .param("learnerId", learnerId)
                .query(Integer.class)
                .single();
        jdbc.sql("""
                        select code from engagement_achievement_policies
                        where enabled = true
                          and ((trigger_type = 'activity_count' and threshold <= :activityCount)
                            or (trigger_type = 'streak' and threshold <= :streak))
                        order by code
                        """)
                .param("activityCount", activityCount)
                .param("streak", streak)
                .query(String.class)
                .list()
                .forEach(code -> award(learnerId, code, now));
    }

    private NotificationPreference preference(UUID learnerId) {
        return jdbc.sql("""
                        select enabled, reminder_time, locale, timezone, updated_at
                        from notification_preferences where learner_id = :learnerId
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> new NotificationPreference(
                        rs.getBoolean("enabled"),
                        rs.getTime("reminder_time") == null
                                ? null
                                : rs.getTime("reminder_time").toLocalTime(),
                        rs.getString("locale"),
                        rs.getString("timezone"),
                        rs.getTimestamp("updated_at").toInstant()))
                .optional()
                .orElse(new NotificationPreference(false, null, "und", "UTC", null));
    }

    private EventPolicy activePolicy(String eventType) {
        return jdbc.sql("""
                        select version, xp_awarded, counts_toward_streak, requires_evidence
                        from engagement_event_policies
                        where event_type = :eventType and enabled = true
                        order by version desc limit 1
                        """)
                .param("eventType", eventType)
                .query((rs, rowNum) -> new EventPolicy(
                        rs.getInt("version"),
                        rs.getInt("xp_awarded"),
                        rs.getBoolean("counts_toward_streak"),
                        rs.getBoolean("requires_evidence")))
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "ENGAGEMENT_EVENT_UNSUPPORTED",
                        "The engagement event type is not supported."));
    }

    private void validateEvidence(
            UUID learnerId, String eventType, String evidenceRef) {
        if (evidenceRef == null || evidenceRef.isBlank()) {
            invalidEvidence();
        }
        boolean valid;
        if ("lesson_completed".equals(eventType)) {
            String[] parts = evidenceRef.split(":", 2);
            valid = parts.length == 2 && jdbc.sql("""
                            select exists(
                              select 1 from learning_completions
                              where learner_id = :learnerId
                                and course_id = :courseId
                                and lesson_id = :lessonId
                                and active = true
                            )
                            """)
                    .param("learnerId", learnerId.toString())
                    .param("courseId", parts.length == 2 ? parts[0] : "")
                    .param("lessonId", parts.length == 2 ? parts[1] : "")
                    .query(Boolean.class)
                    .single();
        } else if ("advanced_practice_completed".equals(eventType)) {
            UUID resultId;
            try {
                resultId = UUID.fromString(evidenceRef);
            } catch (IllegalArgumentException exception) {
                invalidEvidence();
                return;
            }
            valid = jdbc.sql("""
                            select exists(
                              select 1 from advanced_feedback_results
                              where learner_id = :learnerId and id = :resultId
                            )
                            """)
                    .param("learnerId", learnerId)
                    .param("resultId", resultId)
                    .query(Boolean.class)
                    .single();
        } else {
            valid = false;
        }
        if (!valid) {
            invalidEvidence();
        }
    }

    private void invalidEvidence() {
        throw new ApiException(
                HttpStatus.UNPROCESSABLE_CONTENT,
                "ENGAGEMENT_EVIDENCE_INVALID",
                "The activity evidence is missing, invalid, or does not belong to the learner.");
    }

    private DailyLearningPolicy activeDailyLearningPolicy() {
        return jdbc.sql("""
                        select version, review_backlog_limit, quick_practice_exercise_count,
                               default_goal_type, default_goal_target,
                               minutes_goal_min, minutes_goal_max,
                               lessons_goal_min, lessons_goal_max,
                               reviews_goal_min, reviews_goal_max,
                               quiet_hours_start, quiet_hours_end
                        from daily_learning_policies
                        where enabled = true
                        order by version desc limit 1
                        """)
                .query((rs, rowNum) -> new DailyLearningPolicy(
                        rs.getInt("version"),
                        rs.getInt("review_backlog_limit"),
                        rs.getInt("quick_practice_exercise_count"),
                        rs.getString("default_goal_type"),
                        rs.getInt("default_goal_target"),
                        rs.getInt("minutes_goal_min"),
                        rs.getInt("minutes_goal_max"),
                        rs.getInt("lessons_goal_min"),
                        rs.getInt("lessons_goal_max"),
                        rs.getInt("reviews_goal_min"),
                        rs.getInt("reviews_goal_max"),
                        rs.getTime("quiet_hours_start").toLocalTime(),
                        rs.getTime("quiet_hours_end").toLocalTime()))
                .single();
    }

    private DailyGoalStatus dailyGoal(
            UUID learnerId, String timezone, DailyLearningPolicy policy) {
        Map<String, Object> preferences = jdbc.sql("""
                        select preferences::text from learner_profiles
                        where learner_id = :learnerId
                        """)
                .param("learnerId", learnerId)
                .query(String.class)
                .optional()
                .map(this::readPreferences)
                .orElse(Map.of());
        String requestedType = preferences.get("dailyGoalType") instanceof String value
                ? value : policy.defaultGoalType();
        int requestedTarget = numberPreference(
                preferences.get("dailyGoalTarget"),
                numberPreference(preferences.get("dailyGoalMinutes"), policy.defaultGoalTarget()));
        String type = policy.supports(requestedType) ? requestedType : policy.defaultGoalType();
        int target = policy.clamp(type, requestedTarget);
        ZoneId zone = zoneId(timezone);
        LocalDate today = clock.instant().atZone(zone).toLocalDate();
        Instant start = today.atStartOfDay(zone).toInstant();
        Instant end = today.plusDays(1).atStartOfDay(zone).toInstant();
        int completed = switch (type) {
            case "lessons" -> countCompletedLessons(learnerId, start, end);
            case "reviews" -> countCompletedReviews(learnerId, start, end);
            default -> countLearningMinutes(learnerId, start, end);
        };
        return new DailyGoalStatus(type, target, completed, completed >= target);
    }

    private int countLearningMinutes(UUID learnerId, Instant start, Instant end) {
        long milliseconds = jdbc.sql("""
                        select coalesce(sum(response_time_ms), 0)
                        from attempts
                        where learner_id = :learnerId
                          and accepted_at >= :startAt and accepted_at < :endAt
                        """)
                .param("learnerId", learnerId.toString())
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query(Long.class)
                .single();
        return (int) (milliseconds / 60_000L);
    }

    private int countCompletedLessons(UUID learnerId, Instant start, Instant end) {
        return jdbc.sql("""
                        select count(*) from learning_completions
                        where learner_id = :learnerId and active = true
                          and completed_at >= :startAt and completed_at < :endAt
                        """)
                .param("learnerId", learnerId.toString())
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query(Integer.class)
                .single();
    }

    private int countCompletedReviews(UUID learnerId, Instant start, Instant end) {
        return jdbc.sql("""
                        select count(distinct id) from attempts
                        where learner_id = :learnerId
                          and evidence ->> 'practiceMode' = 'daily_quick_practice'
                          and accepted_at >= :startAt and accepted_at < :endAt
                        """)
                .param("learnerId", learnerId.toString())
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query(Integer.class)
                .single();
    }

    private Map<String, Object> readPreferences(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored learner preferences are invalid.", exception);
        }
    }

    private int numberPreference(Object value, int fallback) {
        return value instanceof Number number ? number.intValue() : fallback;
    }

    private ZoneId zoneId(String timezone) {
        try {
            return ZoneId.of(timezone);
        } catch (DateTimeException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "TIMEZONE_INVALID",
                    "The timezone must be a valid IANA zone ID.");
        }
    }

    private Map<String, String> readLocalizedText(String value) {
        try {
            return objectMapper.readValue(value, LOCALIZED_TEXT);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored localized achievement text is invalid.", exception);
        }
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

    private record EventPolicy(
            int version, int xpAwarded, boolean countsTowardStreak, boolean requiresEvidence) {}

    public record Achievement(
            String code,
            Map<String, String> title,
            Map<String, String> description,
            Instant earnedAt) {}

    public record NotificationPreference(
            boolean enabled, LocalTime reminderTime, String locale, String timezone, Instant updatedAt) {}

    public record DailyGoalStatus(
            String type, int target, int completed, boolean achieved) {}

    public record DailyLearningPolicy(
            int version,
            int reviewBacklogLimit,
            int quickPracticeExerciseCount,
            String defaultGoalType,
            int defaultGoalTarget,
            int minutesGoalMin,
            int minutesGoalMax,
            int lessonsGoalMin,
            int lessonsGoalMax,
            int reviewsGoalMin,
            int reviewsGoalMax,
            LocalTime quietHoursStart,
            LocalTime quietHoursEnd) {

        boolean supports(String type) {
            return "minutes".equals(type) || "lessons".equals(type) || "reviews".equals(type);
        }

        int clamp(String type, int target) {
            return switch (type) {
                case "lessons" -> Math.clamp(target, lessonsGoalMin, lessonsGoalMax);
                case "reviews" -> Math.clamp(target, reviewsGoalMin, reviewsGoalMax);
                default -> Math.clamp(target, minutesGoalMin, minutesGoalMax);
            };
        }

        boolean isQuietTime(LocalTime time) {
            if (quietHoursStart.equals(quietHoursEnd)) {
                return false;
            }
            if (quietHoursStart.isBefore(quietHoursEnd)) {
                return !time.isBefore(quietHoursStart) && time.isBefore(quietHoursEnd);
            }
            return !time.isBefore(quietHoursStart) || time.isBefore(quietHoursEnd);
        }
    }

    public record EngagementStatus(
            int currentStreak,
            int longestStreak,
            int xp,
            LocalDate lastLearningDate,
            List<Achievement> achievements,
            NotificationPreference notificationPreference,
            DailyLearningPolicy dailyLearningPolicy,
            DailyGoalStatus dailyGoal) {}
}

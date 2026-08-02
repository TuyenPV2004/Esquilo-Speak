package com.esquilospeak.productquality;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.AccountDataParticipant;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
@Order(260)
public class ProductQualityService implements AccountDataParticipant {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};
    private static final Set<String> ALLOWED_ATTRIBUTES = Set.of(
            "result",
            "reasonCode",
            "practiceMode",
            "retryIndex",
            "hintUsed",
            "responseTimeBucket",
            "correct",
            "feedbackHelpful",
            "recommendationPolicyVersion",
            "recommendationKind",
            "usedFallback");
    private static final Set<String> ALLOWED_EVENTS = Set.of(
            "learning_session_started", "learning_session_completed", "learning_session_abandoned",
            "lesson_started", "lesson_completed", "lesson_abandoned",
            "review_started", "review_completed", "review_abandoned",
            "practice_started", "practice_completed", "practice_abandoned",
            "exercise_presented", "exercise_submitted", "recommendation_presented",
            "recommendation_selected", "feedback_helpfulness_recorded");

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    ProductQualityService(JdbcClient jdbc, ObjectMapper objectMapper, Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional
    public IngestResult ingest(UUID learnerId, List<AnalyticsEventInput> events) {
        requireTelemetryConsent(learnerId);
        RetentionPolicy retention = retentionPolicy();
        Instant now = clock.instant();
        int accepted = 0;
        int duplicate = 0;
        for (AnalyticsEventInput event : events) {
            validateEvent(event, now, retention.retentionDays());
            int inserted = jdbc.sql("""
                            insert into analytics_events (
                              id, learner_id, client_event_id, event_name, event_version,
                              occurred_at, received_at, course_id, unit_id, lesson_id,
                              lesson_version, exercise_id, exercise_type, session_kind,
                              attributes, expires_at
                            ) values (
                              :id, :learnerId, :clientEventId, :eventName, 1,
                              :occurredAt, :receivedAt, :courseId, :unitId, :lessonId,
                              :lessonVersion, :exerciseId, :exerciseType, :sessionKind,
                              cast(:attributes as jsonb), :expiresAt
                            ) on conflict (learner_id, client_event_id) do nothing
                            """)
                    .param("id", UUID.randomUUID())
                    .param("learnerId", learnerId)
                    .param("clientEventId", event.clientEventId())
                    .param("eventName", event.name())
                    .param("occurredAt", Timestamp.from(event.occurredAt()))
                    .param("receivedAt", Timestamp.from(now))
                    .param("courseId", event.courseId())
                    .param("unitId", event.unitId())
                    .param("lessonId", event.lessonId())
                    .param("lessonVersion", event.lessonVersion())
                    .param("exerciseId", event.exerciseId())
                    .param("exerciseType", event.exerciseType())
                    .param("sessionKind", event.sessionKind())
                    .param("attributes", writeJson(event.attributes()))
                    .param("expiresAt", Timestamp.from(
                            event.occurredAt().plus(retention.retentionDays(), ChronoUnit.DAYS)))
                    .update();
            accepted += inserted;
            duplicate += inserted == 0 ? 1 : 0;
        }
        return new IngestResult(accepted, duplicate, retention.version(), retention.retentionDays());
    }

    @Transactional(readOnly = true)
    public Dashboard dashboard(String courseId, LocalDate from, LocalDate to) {
        if (to.isBefore(from) || ChronoUnit.DAYS.between(from, to) > 366) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "INVALID_METRIC_WINDOW",
                    "The metric window must be ordered and no longer than 366 days.");
        }
        Instant start = from.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant end = to.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        CompletionCounts firstLesson = firstLessonCompletion(courseId, start, end);
        Instant weeklyStart = start.isAfter(end.minus(7, ChronoUnit.DAYS))
                ? start : end.minus(7, ChronoUnit.DAYS);
        long completedSessions = weeklyEvidenceLearners(courseId, weeklyStart, end);
        CompletionCounts unitOne = jdbc.sql("""
                        with first_unit as (
                          select unit_id from product_quality_lesson_dimension
                          where course_id = :courseId and unit_id is not null
                            and status = 'published'
                          order by position limit 1
                        ), unit_one as (
                          select id, version from product_quality_lesson_dimension
                          where course_id = :courseId
                            and unit_id = (select unit_id from first_unit)
                            and status = 'published'
                        ), eligible as (
                          select distinct attempt.learner_id
                          from product_quality_attempt_facts attempt join unit_one lesson
                            on lesson.id = attempt.lesson_id
                           and lesson.version = attempt.lesson_version
                          where attempt.course_id = :courseId
                            and attempt.accepted_at >= :startAt
                            and attempt.accepted_at < :endAt
                        ), completion_counts as (
                          select c.learner_id, count(*) completed
                          from product_quality_completion_facts c
                          join eligible on eligible.learner_id = c.learner_id
                          join unit_one u
                            on u.id = c.lesson_id and u.version = c.lesson_version
                          where c.course_id = :courseId and c.active = true
                            and c.completed_at < :endAt
                          group by c.learner_id
                        )
                        select (select count(*) from eligible) eligible,
                               count(*) filter (
                                 where completed = (select count(*) from unit_one)
                                   and (select count(*) from unit_one) > 0
                               ) completed
                        from completion_counts
                        """)
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query((rs, rowNum) -> new CompletionCounts(
                        rs.getLong("eligible"), rs.getLong("completed")))
                .single();
        RetentionCounts retention = retentionCounts(courseId, from, to);
        FunnelCounts review = funnelCounts("review", courseId, start, end);
        AttemptSignals attemptSignals = attemptSignals(courseId, start, end);
        long reports = jdbc.sql("""
                        select count(*) from product_quality_support_facts ticket
                        where ticket.ticket_type = 'content_report'
                          and ticket.created_at >= :startAt and ticket.created_at < :endAt
                          and exists (
                            select 1 from product_quality_lesson_dimension lesson
                            where lesson.course_id = :courseId
                              and (ticket.content_ref = lesson.id
                                or ticket.content_ref like lesson.id || ':%')
                          )
                        """)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .param("courseId", courseId)
                .query(Long.class)
                .single();
        List<DropOff> dropOff = jdbc.sql("""
                        select coalesce(lesson_id, 'unknown') lesson_id,
                               coalesce(exercise_type, 'unknown') exercise_type,
                               event_name, count(*) event_count
                        from analytics_events
                        where event_name in ('lesson_abandoned', 'review_abandoned', 'practice_abandoned')
                          and occurred_at >= :startAt and occurred_at < :endAt
                          and (:courseId is null or course_id = :courseId)
                        group by lesson_id, exercise_type, event_name
                        order by event_count desc, lesson_id, exercise_type
                        """)
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query((rs, rowNum) -> new DropOff(
                        rs.getString("lesson_id"),
                        rs.getString("exercise_type"),
                        rs.getString("event_name"),
                        rs.getLong("event_count")))
                .list();
        List<Metric> metrics = List.of(
                Metric.rate("first_lesson_completion", firstLesson.completed(), firstLesson.eligible(), "canonical"),
                Metric.rate("unit_one_completion", unitOne.completed(), unitOne.eligible(), "canonical"),
                Metric.count("weekly_evidence_learner", completedSessions, "canonical"),
                Metric.rate("d1_retention", retention.dayOne(), retention.dayOneEligible(), "canonical"),
                Metric.rate("d7_retention", retention.daySeven(), retention.daySevenEligible(), "canonical"),
                Metric.rate("review_completion", review.completed(), review.started(), "consented_telemetry"),
                Metric.rate("attempt_correctness", attemptSignals.correct(), attemptSignals.total(), "canonical"),
                Metric.rate("attempt_retry_usage", attemptSignals.retried(), attemptSignals.total(), "canonical"),
                Metric.rate("attempt_hint_usage", attemptSignals.hinted(), attemptSignals.total(), "canonical"),
                Metric.average("attempt_response_time_ms", attemptSignals.averageResponseTimeMs(), attemptSignals.total(), "canonical"),
                Metric.rate("content_report_rate", reports, attemptSignals.total(), "canonical"));
        return new Dashboard(
                "product-quality-dashboard-v1",
                courseId,
                from,
                to,
                metrics,
                dropOff,
                review.started(),
                "Optional funnel metrics include only learners who granted operational telemetry consent.");
    }

    @Transactional
    public List<QualityItem> qualityQueue(String courseId) {
        refreshContentReports(courseId);
        refreshDifficultyAnomalies(courseId);
        refreshFeedbackUsefulness(courseId);
        return jdbc.sql("""
                        select id, source_type, content_ref, course_id, lesson_id, exercise_id,
                               signal_code, evidence_count, observed_rate, priority, status,
                               policy_version, first_observed_at, last_observed_at, updated_at
                        from content_quality_items
                        where (:courseId is null or course_id = :courseId)
                          and status in ('open', 'triaged')
                        order by case priority
                                   when 'critical' then 0 when 'high' then 1
                                   when 'medium' then 2 else 3 end,
                                 last_observed_at desc, content_ref
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> qualityItem(rs))
                .list();
    }

    @Transactional
    public QualityItem updateQualityStatus(UUID itemId, String status) {
        int updated = jdbc.sql("""
                        update content_quality_items set status = :status, updated_at = :now
                        where id = :id
                        """)
                .param("status", status)
                .param("now", Timestamp.from(clock.instant()))
                .param("id", itemId)
                .update();
        if (updated == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "QUALITY_ITEM_NOT_FOUND", "Quality item not found.");
        }
        return jdbc.sql("""
                        select id, source_type, content_ref, course_id, lesson_id, exercise_id,
                               signal_code, evidence_count, observed_rate, priority, status,
                               policy_version, first_observed_at, last_observed_at, updated_at
                        from content_quality_items where id = :id
                        """)
                .param("id", itemId)
                .query((rs, rowNum) -> qualityItem(rs))
                .single();
    }

    @Transactional(readOnly = true)
    public Recommendation recommend(UUID learnerId, String courseId) {
        RecommendationPolicy policy = recommendationPolicy();
        Recommendation due = jdbc.sql("""
                        select schedule.concept_id from product_quality_review_dimension schedule
                        where schedule.learner_id = :learnerId and schedule.due_at <= :now
                          and (:courseId is null or exists (
                            select 1 from product_quality_lesson_dimension lesson
                            cross join lateral jsonb_array_elements(lesson.content->'exercises') exercise
                            where lesson.course_id = :courseId
                              and lesson.status = 'published'
                              and jsonb_exists(exercise->'conceptIds', schedule.concept_id)
                          ))
                        order by due_at, concept_id limit 1
                        """)
                .param("learnerId", learnerId.toString())
                .param("now", Timestamp.from(clock.instant()))
                .param("courseId", courseId)
                .query((rs, rowNum) -> recommendation(
                        policy, "review_due", "REVIEW_DUE_FIRST", rs.getString("concept_id"), false))
                .optional()
                .orElse(null);
        if (due != null) {
            return due;
        }
        Recommendation weak = jdbc.sql("""
                        select mastery.concept_id from product_quality_mastery_dimension mastery
                        where mastery.learner_id = :learnerId and mastery.score < :threshold
                          and (:courseId is null or exists (
                            select 1 from product_quality_lesson_dimension lesson
                            cross join lateral jsonb_array_elements(lesson.content->'exercises') exercise
                            where lesson.course_id = :courseId
                              and lesson.status = 'published'
                              and jsonb_exists(exercise->'conceptIds', mastery.concept_id)
                          ))
                        order by score, concept_id limit 1
                        """)
                .param("learnerId", learnerId.toString())
                .param("threshold", policy.weakMasteryThreshold())
                .param("courseId", courseId)
                .query((rs, rowNum) -> recommendation(
                        policy, "strengthen_weak_concept", "LOWEST_MASTERY_FIRST",
                        rs.getString("concept_id"), false))
                .optional()
                .orElse(null);
        if (weak != null) {
            return weak;
        }
        boolean hasEvidence = jdbc.sql("""
                        select exists(
                          select 1 from product_quality_mastery_dimension mastery
                          where mastery.learner_id = :learnerId
                            and (:courseId is null or exists (
                              select 1 from product_quality_lesson_dimension lesson
                              cross join lateral jsonb_array_elements(lesson.content->'exercises') exercise
                              where lesson.course_id = :courseId
                                and lesson.status = 'published'
                                and jsonb_exists(exercise->'conceptIds', mastery.concept_id)
                            ))
                        )
                        """)
                .param("learnerId", learnerId.toString())
                .param("courseId", courseId)
                .query(Boolean.class)
                .single();
        if (hasEvidence) {
            return recommendation(policy, "continue_learning", "NO_DUE_OR_WEAK_CONCEPT", null, false);
        }
        return recommendation(policy, "start_learning", "NO_LEARNING_EVIDENCE", null, true);
    }

    @Transactional
    public int purgeExpired() {
        return jdbc.sql("delete from analytics_events where expires_at <= :now")
                .param("now", Timestamp.from(clock.instant()))
                .update();
    }

    private void requireTelemetryConsent(UUID learnerId) {
        boolean granted = jdbc.sql("""
                        select coalesce((
                          select granted from consent_records
                          where learner_id = :learnerId and purpose = 'operational_telemetry'
                          order by recorded_at desc, id desc limit 1
                        ), false)
                        """)
                .param("learnerId", learnerId)
                .query(Boolean.class)
                .single();
        if (!granted) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "ANALYTICS_CONSENT_REQUIRED",
                    "Operational telemetry consent is required for analytics events.");
        }
    }

    private void validateEvent(AnalyticsEventInput event, Instant now, int retentionDays) {
        if (!ALLOWED_EVENTS.contains(event.name()) || event.eventVersion() != 1) {
            throw invalidEvent("The analytics event name or version is not supported.");
        }
        if (event.occurredAt().isAfter(now.plus(5, ChronoUnit.MINUTES))
                || event.occurredAt().isBefore(now.minus(retentionDays, ChronoUnit.DAYS))) {
            throw invalidEvent("The analytics event timestamp is outside the accepted window.");
        }
        if (!ALLOWED_ATTRIBUTES.containsAll(event.attributes().keySet())) {
            throw invalidEvent("The analytics event contains an attribute that is not allowlisted.");
        }
        boolean primitive = event.attributes().values().stream().allMatch(value ->
                value == null || value instanceof String || value instanceof Number || value instanceof Boolean);
        if (!primitive) {
            throw invalidEvent("Analytics attributes must be scalar values.");
        }
        boolean boundedStrings = event.attributes().values().stream()
                .filter(String.class::isInstance)
                .map(String.class::cast)
                .allMatch(value -> value.length() <= 100);
        if (!boundedStrings) {
            throw invalidEvent("Analytics string attributes must not exceed 100 characters.");
        }
    }

    private ApiException invalidEvent(String message) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "ANALYTICS_EVENT_INVALID", message);
    }

    private RetentionPolicy retentionPolicy() {
        return jdbc.sql("""
                        select version, retention_days from analytics_retention_policies
                        where policy_key = 'learning_product_analytics' and enabled = true
                        order by version desc limit 1
                        """)
                .query((rs, rowNum) -> new RetentionPolicy(rs.getInt("version"), rs.getInt("retention_days")))
                .single();
    }

    private RecommendationPolicy recommendationPolicy() {
        return jdbc.sql("""
                        select version, weak_mastery_threshold, evaluation_dataset_version,
                               rollback_version
                        from recommendation_policies
                        where policy_key = 'daily_next_learning' and enabled = true
                        order by version desc limit 1
                        """)
                .query((rs, rowNum) -> new RecommendationPolicy(
                        rs.getInt("version"),
                        rs.getDouble("weak_mastery_threshold"),
                        rs.getString("evaluation_dataset_version"),
                        (Integer) rs.getObject("rollback_version")))
                .single();
    }

    private Recommendation recommendation(
            RecommendationPolicy policy, String kind, String explanationCode, String conceptId, boolean fallback) {
        return new Recommendation(
                policy.version(),
                kind,
                explanationCode,
                conceptId,
                fallback,
                Map.of(
                        "weakMasteryThreshold", policy.weakMasteryThreshold(),
                        "evaluationDatasetVersion", policy.evaluationDatasetVersion()),
                policy.rollbackVersion());
    }

    private CompletionCounts firstLessonCompletion(String courseId, Instant start, Instant end) {
        return jdbc.sql("""
                        with starts as (
                          select distinct on (attempt.learner_id)
                                 attempt.learner_id, attempt.lesson_id,
                                 attempt.lesson_version, attempt.accepted_at started_at
                          from product_quality_attempt_facts attempt
                          join product_quality_lesson_dimension lesson on lesson.id = attempt.lesson_id
                            and lesson.version = attempt.lesson_version
                          where attempt.course_id = :courseId and lesson.position = 1
                            and lesson.status = 'published'
                            and attempt.accepted_at >= :startAt
                            and attempt.accepted_at < :endAt
                          order by attempt.learner_id, attempt.accepted_at, attempt.id
                        )
                        select count(*) eligible,
                               count(*) filter (where exists (
                                 select 1 from product_quality_completion_facts completion
                                 where completion.learner_id = starts.learner_id
                                   and completion.course_id = :courseId
                                   and completion.lesson_id = starts.lesson_id
                                   and completion.lesson_version = starts.lesson_version
                                   and completion.active = true
                                   and completion.completed_at >= starts.started_at
                                   and completion.completed_at < :endAt
                               )) completed
                        from starts
                        """)
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query((rs, rowNum) -> new CompletionCounts(
                        rs.getLong("eligible"), rs.getLong("completed")))
                .single();
    }

    private long weeklyEvidenceLearners(String courseId, Instant start, Instant end) {
        return jdbc.sql("""
                        select count(distinct learner_id) from (
                          select session.learner_id learner_id
                          from product_quality_session_facts session
                          where session.course_id = :courseId and session.state = 'completed'
                            and session.completed_at >= :startAt and session.completed_at < :endAt
                            and exists (
                              select 1 from product_quality_attempt_facts attempt where attempt.session_id = session.id
                            )
                          union
                          select completion.learner_id
                          from product_quality_completion_facts completion
                          where completion.course_id = :courseId and completion.active = true
                            and completion.completed_at >= :startAt and completion.completed_at < :endAt
                          union
                          select event.learner_id::text
                          from product_quality_engagement_facts event
                          where event.event_type = 'daily_session_completed'
                            and event.created_at >= :startAt and event.created_at < :endAt
                            and exists (
                              select 1 from product_quality_attempt_facts attempt
                              where attempt.learner_id = event.learner_id::text
                                and attempt.course_id = :courseId
                                and attempt.accepted_at::date = event.occurred_on
                            )
                        ) evidence
                        """)
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query(Long.class)
                .single();
    }

    private RetentionCounts retentionCounts(String courseId, LocalDate from, LocalDate to) {
        LocalDate today = clock.instant().atZone(ZoneOffset.UTC).toLocalDate();
        LocalDate dayOneCutoff = to.isBefore(today.minusDays(1)) ? to : today.minusDays(1);
        LocalDate daySevenCutoff = to.isBefore(today.minusDays(7)) ? to : today.minusDays(7);
        return jdbc.sql("""
                        with first_activity as (
                          select learner_id, min(accepted_at::date) cohort_date
                          from product_quality_attempt_facts
                          where course_id = :courseId group by learner_id
                        ), cohort as (
                          select learner_id, cohort_date from first_activity
                          where cohort_date between :fromDate and :toDate
                        )
                        select count(*) filter (where cohort_date <= :dayOneCutoff) day_one_eligible,
                               count(*) filter (where cohort_date <= :dayOneCutoff and exists (
                                 select 1 from product_quality_attempt_facts a
                                 where a.learner_id = cohort.learner_id
                                   and a.course_id = :courseId
                                   and a.accepted_at::date = cohort.cohort_date + 1
                               )) day_one,
                               count(*) filter (where cohort_date <= :daySevenCutoff) day_seven_eligible,
                               count(*) filter (where cohort_date <= :daySevenCutoff and exists (
                                 select 1 from product_quality_attempt_facts a
                                 where a.learner_id = cohort.learner_id
                                   and a.course_id = :courseId
                                   and a.accepted_at::date = cohort.cohort_date + 7
                               )) day_seven
                        from cohort
                        """)
                .param("courseId", courseId)
                .param("fromDate", java.sql.Date.valueOf(from))
                .param("toDate", java.sql.Date.valueOf(to))
                .param("dayOneCutoff", java.sql.Date.valueOf(dayOneCutoff))
                .param("daySevenCutoff", java.sql.Date.valueOf(daySevenCutoff))
                .query((rs, rowNum) -> new RetentionCounts(
                        rs.getLong("day_one_eligible"),
                        rs.getLong("day_one"),
                        rs.getLong("day_seven_eligible"),
                        rs.getLong("day_seven")))
                .single();
    }

    private FunnelCounts funnelCounts(String funnel, String courseId, Instant start, Instant end) {
        return jdbc.sql("""
                        select count(*) filter (where event_name = :started) started,
                               count(*) filter (where event_name = :completed) completed
                        from analytics_events
                        where occurred_at >= :startAt and occurred_at < :endAt
                          and (:courseId is null or course_id = :courseId)
                        """)
                .param("started", funnel + "_started")
                .param("completed", funnel + "_completed")
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query((rs, rowNum) -> new FunnelCounts(rs.getLong("started"), rs.getLong("completed")))
                .single();
    }

    private AttemptSignals attemptSignals(String courseId, Instant start, Instant end) {
        return jdbc.sql("""
                        select count(*) total,
                               count(*) filter (where correct) correct,
                               count(*) filter (where coalesce((evidence->>'retryIndex')::integer, 0) > 0) retried,
                               count(*) filter (where coalesce((evidence->>'hintUsed')::boolean, false)) hinted,
                               coalesce(avg(response_time_ms), 0) average_response_time_ms
                        from product_quality_attempt_facts
                        where course_id = :courseId and accepted_at >= :startAt and accepted_at < :endAt
                        """)
                .param("courseId", courseId)
                .param("startAt", Timestamp.from(start))
                .param("endAt", Timestamp.from(end))
                .query((rs, rowNum) -> new AttemptSignals(
                        rs.getLong("total"),
                        rs.getLong("correct"),
                        rs.getLong("retried"),
                        rs.getLong("hinted"),
                        rs.getDouble("average_response_time_ms")))
                .single();
    }

    private void refreshContentReports(String courseId) {
        jdbc.sql("""
                        select coalesce(ticket.content_ref, 'unscoped') content_ref,
                               max(lesson.course_id) course_id,
                               count(distinct ticket.id) evidence_count,
                               min(ticket.created_at) first_at, max(ticket.created_at) last_at
                        from product_quality_support_facts ticket
                        left join product_quality_lesson_dimension lesson
                          on ticket.content_ref = lesson.id
                          or ticket.content_ref like lesson.id || ':%'
                        where ticket.ticket_type = 'content_report'
                          and ticket.status in ('open', 'triaged')
                          and (:courseId is null or lesson.course_id = :courseId)
                        group by ticket.content_ref
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> new QualitySignal(
                        "content_report",
                        rs.getString("content_ref"),
                        rs.getString("content_ref"),
                        rs.getString("course_id"),
                        contentPart(rs.getString("content_ref"), "lesson"),
                        contentPart(rs.getString("content_ref"), "exercise"),
                        "CONTENT_REPORT_OPEN",
                        rs.getInt("evidence_count"),
                        null,
                        rs.getInt("evidence_count") >= 3 ? "high" : "medium",
                        rs.getTimestamp("first_at").toInstant(),
                        rs.getTimestamp("last_at").toInstant()))
                .list()
                .forEach(this::upsertSignal);
    }

    private void refreshDifficultyAnomalies(String courseId) {
        jdbc.sql("""
                        select a.course_id, a.lesson_id, a.exercise_id,
                               count(*) evidence_count,
                               avg(case when a.correct then 1.0 else 0.0 end) observed_rate
                        from product_quality_attempt_facts a
                        where (:courseId is null or a.course_id = :courseId)
                        group by a.course_id, a.lesson_id, a.exercise_id
                        having count(*) >= 5
                           and avg(case when a.correct then 1.0 else 0.0 end) < 0.60
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> new QualitySignal(
                        "difficulty_anomaly",
                        rs.getString("course_id") + ":" + rs.getString("lesson_id") + ":" + rs.getString("exercise_id"),
                        rs.getString("lesson_id") + ":" + rs.getString("exercise_id"),
                        rs.getString("course_id"),
                        rs.getString("lesson_id"),
                        rs.getString("exercise_id"),
                        "LOW_CORRECTNESS",
                        rs.getInt("evidence_count"),
                        rs.getDouble("observed_rate"),
                        rs.getDouble("observed_rate") < 0.35 ? "high" : "medium",
                        clock.instant(),
                        clock.instant()))
                .list()
                .forEach(this::upsertSignal);
    }

    private void refreshFeedbackUsefulness(String courseId) {
        jdbc.sql("""
                        select coalesce(lesson_id, 'unknown') lesson_id,
                               coalesce(exercise_id, 'unknown') exercise_id,
                               count(*) evidence_count,
                               avg(case when (attributes->>'feedbackHelpful')::boolean then 1.0 else 0.0 end) observed_rate,
                               min(occurred_at) first_at, max(occurred_at) last_at
                        from analytics_events
                        where event_name = 'feedback_helpfulness_recorded'
                          and jsonb_exists(attributes, 'feedbackHelpful')
                          and (:courseId is null or course_id = :courseId)
                        group by lesson_id, exercise_id
                        having count(*) >= 5
                           and avg(case when (attributes->>'feedbackHelpful')::boolean then 1.0 else 0.0 end) < 0.60
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> new QualitySignal(
                        "feedback_usefulness",
                        rs.getString("lesson_id") + ":" + rs.getString("exercise_id"),
                        rs.getString("lesson_id") + ":" + rs.getString("exercise_id"),
                        courseId,
                        rs.getString("lesson_id"),
                        rs.getString("exercise_id"),
                        "LOW_FEEDBACK_USEFULNESS",
                        rs.getInt("evidence_count"),
                        rs.getDouble("observed_rate"),
                        "medium",
                        rs.getTimestamp("first_at").toInstant(),
                        rs.getTimestamp("last_at").toInstant()))
                .list()
                .forEach(this::upsertSignal);
    }

    private void upsertSignal(QualitySignal signal) {
        jdbc.sql("""
                        insert into content_quality_items (
                          id, source_type, source_ref, content_ref, course_id, lesson_id,
                          exercise_id, signal_code, evidence_count, observed_rate, priority,
                          status, policy_version, first_observed_at, last_observed_at, updated_at
                        ) values (
                          :id, :sourceType, :sourceRef, :contentRef, :courseId, :lessonId,
                          :exerciseId, :signalCode, :evidenceCount, :observedRate, :priority,
                          'open', 1, :firstObservedAt, :lastObservedAt, :updatedAt
                        ) on conflict (source_type, source_ref) do update set
                          content_ref = excluded.content_ref,
                          course_id = excluded.course_id,
                          lesson_id = excluded.lesson_id,
                          exercise_id = excluded.exercise_id,
                          signal_code = excluded.signal_code,
                          evidence_count = excluded.evidence_count,
                          observed_rate = excluded.observed_rate,
                          priority = excluded.priority,
                          first_observed_at = least(content_quality_items.first_observed_at, excluded.first_observed_at),
                          last_observed_at = excluded.last_observed_at,
                          updated_at = excluded.updated_at
                        """)
                .param("id", UUID.randomUUID())
                .param("sourceType", signal.sourceType())
                .param("sourceRef", signal.sourceRef())
                .param("contentRef", signal.contentRef())
                .param("courseId", signal.courseId())
                .param("lessonId", signal.lessonId())
                .param("exerciseId", signal.exerciseId())
                .param("signalCode", signal.signalCode())
                .param("evidenceCount", signal.evidenceCount())
                .param("observedRate", signal.observedRate())
                .param("priority", signal.priority())
                .param("firstObservedAt", Timestamp.from(signal.firstObservedAt()))
                .param("lastObservedAt", Timestamp.from(signal.lastObservedAt()))
                .param("updatedAt", Timestamp.from(clock.instant()))
                .update();
    }

    private String contentPart(String contentRef, String prefix) {
        if (contentRef == null || !contentRef.contains(":")) {
            return "lesson".equals(prefix) ? contentRef : null;
        }
        String[] parts = contentRef.split(":", 2);
        return "lesson".equals(prefix) ? parts[0] : parts[1];
    }

    private QualityItem qualityItem(java.sql.ResultSet rs) throws java.sql.SQLException {
        Number rate = (Number) rs.getObject("observed_rate");
        return new QualityItem(
                rs.getObject("id", UUID.class),
                rs.getString("source_type"),
                rs.getString("content_ref"),
                rs.getString("course_id"),
                rs.getString("lesson_id"),
                rs.getString("exercise_id"),
                rs.getString("signal_code"),
                rs.getInt("evidence_count"),
                rate == null ? null : rate.doubleValue(),
                rs.getString("priority"),
                rs.getString("status"),
                rs.getInt("policy_version"),
                rs.getTimestamp("first_observed_at").toInstant(),
                rs.getTimestamp("last_observed_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant());
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize analytics attributes.", exception);
        }
    }

    private Map<String, Object> readJson(String value) {
        try {
            return objectMapper.readValue(value, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored analytics attributes are invalid.", exception);
        }
    }

    @Override
    public String dataDomain() {
        return "product_quality_analytics";
    }

    @Override
    @Transactional(readOnly = true)
    public Map<String, Object> exportData(UUID learnerId) {
        List<Map<String, Object>> events = jdbc.sql("""
                        select client_event_id, event_name, event_version, occurred_at,
                               course_id, unit_id, lesson_id, lesson_version, exercise_id,
                               exercise_type, session_kind, attributes::text
                        from analytics_events where learner_id = :learnerId
                        order by occurred_at, client_event_id
                        """)
                .param("learnerId", learnerId)
                .query((rs, rowNum) -> {
                    Map<String, Object> event = new LinkedHashMap<>();
                    event.put("clientEventId", rs.getObject("client_event_id", UUID.class));
                    event.put("name", rs.getString("event_name"));
                    event.put("eventVersion", rs.getInt("event_version"));
                    event.put("occurredAt", rs.getTimestamp("occurred_at").toInstant());
                    event.put("courseId", rs.getString("course_id"));
                    event.put("unitId", rs.getString("unit_id"));
                    event.put("lessonId", rs.getString("lesson_id"));
                    event.put("lessonVersion", rs.getObject("lesson_version"));
                    event.put("exerciseId", rs.getString("exercise_id"));
                    event.put("exerciseType", rs.getString("exercise_type"));
                    event.put("sessionKind", rs.getString("session_kind"));
                    event.put("attributes", readJson(rs.getString("attributes")));
                    return event;
                })
                .list();
        return Map.of("events", events);
    }

    @Override
    @Transactional
    public void deleteData(UUID learnerId) {
        jdbc.sql("delete from analytics_events where learner_id = :learnerId")
                .param("learnerId", learnerId)
                .update();
    }

    public record AnalyticsEventInput(
            UUID clientEventId,
            String name,
            int eventVersion,
            Instant occurredAt,
            String courseId,
            String unitId,
            String lessonId,
            Integer lessonVersion,
            String exerciseId,
            String exerciseType,
            String sessionKind,
            Map<String, Object> attributes) {}

    public record IngestResult(int accepted, int duplicates, int retentionPolicyVersion, int retentionDays) {}

    public record Metric(
            String code, long numerator, long denominator, Double value, String source, long sampleSize) {
        static Metric rate(String code, long numerator, long denominator, String source) {
            return new Metric(code, numerator, denominator,
                    denominator == 0 ? null : (double) numerator / denominator, source, denominator);
        }

        static Metric count(String code, long value, String source) {
            return new Metric(code, value, 1, (double) value, source, value);
        }

        static Metric average(String code, double value, long sampleSize, String source) {
            return new Metric(code, 0, 0, sampleSize == 0 ? null : value, source, sampleSize);
        }
    }

    public record DropOff(String lessonId, String exerciseType, String eventName, long eventCount) {}

    public record Dashboard(
            String schemaVersion,
            String courseId,
            LocalDate from,
            LocalDate to,
            List<Metric> metrics,
            List<DropOff> dropOff,
            long consentedFunnelSampleSize,
            String samplingNote) {}

    public record QualityItem(
            UUID id,
            String sourceType,
            String contentRef,
            String courseId,
            String lessonId,
            String exerciseId,
            String signalCode,
            int evidenceCount,
            Double observedRate,
            String priority,
            String status,
            int policyVersion,
            Instant firstObservedAt,
            Instant lastObservedAt,
            Instant updatedAt) {}

    public record Recommendation(
            int policyVersion,
            String kind,
            String explanationCode,
            String conceptId,
            boolean usedFallback,
            Map<String, Object> inputs,
            Integer rollbackVersion) {}

    private record RetentionPolicy(int version, int retentionDays) {}
    private record RecommendationPolicy(
            int version, double weakMasteryThreshold, String evaluationDatasetVersion, Integer rollbackVersion) {}
    private record CompletionCounts(long eligible, long completed) {}
    private record RetentionCounts(
            long dayOneEligible, long dayOne, long daySevenEligible, long daySeven) {}
    private record FunnelCounts(long started, long completed) {}
    private record AttemptSignals(
            long total, long correct, long retried, long hinted, double averageResponseTimeMs) {}
    private record QualitySignal(
            String sourceType,
            String sourceRef,
            String contentRef,
            String courseId,
            String lessonId,
            String exerciseId,
            String signalCode,
            int evidenceCount,
            Double observedRate,
            String priority,
            Instant firstObservedAt,
            Instant lastObservedAt) {}
}

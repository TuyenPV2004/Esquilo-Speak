package com.esquilospeak.curriculumcontent;

import com.esquilospeak.ApiException;
import com.fasterxml.jackson.annotation.JsonValue;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class CurriculumContentAdminService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};
    private static final Set<String> SKILLS =
            Set.of("reading", "listening", "writing", "speaking", "vocabulary", "grammar");
    private static final Set<String> REQUIRED_REVIEW_CHECKS = Set.of(
            "schema",
            "references",
            "pedagogy",
            "language",
            "media-accessibility",
            "answer-integrity",
            "preview");

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public CurriculumContentAdminService(JdbcClient jdbc, ObjectMapper objectMapper, Clock clock) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional
    public ContentVersion saveDraft(
            Jwt actor, String courseId, int version, CourseVersionDraft draft) {
        validateDraft(courseId, version, draft);
        ContentVersion existing = findVersion(courseId, version);
        if (existing != null && existing.state() != ContentState.DRAFT) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONTENT_VERSION_IMMUTABLE",
                    "Only a draft content version can be replaced.");
        }

        Instant now = clock.instant();
        Map<String, Object> coursePayload = coursePayload(courseId, version, draft);
        jdbc.sql("""
                        insert into courses (
                            id, source_language, target_language, published, payload
                        ) values (
                            :courseId, :sourceLanguage, :targetLanguage, false,
                            cast(:payload as jsonb)
                        )
                        on conflict (id) do update
                        set source_language = excluded.source_language,
                            target_language = excluded.target_language
                        """)
                .param("courseId", courseId)
                .param("sourceLanguage", draft.sourceLanguage())
                .param("targetLanguage", draft.targetLanguage())
                .param("payload", writeJson(coursePayload))
                .update();
        if (existing == null) {
            jdbc.sql("""
                            insert into course_versions (
                                course_id, version, state, source_language, target_language,
                                locale, compatibility_version,
                                proficiency_framework_code, proficiency_framework_version,
                                entry_level_code, target_level_code,
                                content, owner_name, license_name, created_at, updated_at
                            ) values (
                                :courseId, :version, 'draft', :sourceLanguage,
                                :targetLanguage, :locale, :compatibilityVersion,
                                :frameworkCode, :frameworkVersion,
                                :entryLevelCode, :targetLevelCode,
                                cast(:content as jsonb), :ownerName, :licenseName,
                                :now, :now
                            )
                            """)
                    .param("courseId", courseId)
                    .param("version", version)
                    .param("sourceLanguage", draft.sourceLanguage())
                    .param("targetLanguage", draft.targetLanguage())
                    .param("locale", draft.locale())
                    .param("compatibilityVersion", draft.compatibilityVersion())
                    .param("frameworkCode", draft.proficiency().frameworkCode())
                    .param("frameworkVersion", draft.proficiency().frameworkVersion())
                    .param("entryLevelCode", draft.proficiency().entryLevelCode())
                    .param("targetLevelCode", draft.proficiency().targetLevelCode())
                    .param("content", writeJson(coursePayload))
                    .param("ownerName", draft.owner())
                    .param("licenseName", draft.license())
                    .param("now", Timestamp.from(now))
                    .update();
        } else {
            jdbc.sql("""
                            update course_versions
                            set source_language = :sourceLanguage,
                                target_language = :targetLanguage,
                                locale = :locale,
                                compatibility_version = :compatibilityVersion,
                                proficiency_framework_code = :frameworkCode,
                                proficiency_framework_version = :frameworkVersion,
                                entry_level_code = :entryLevelCode,
                                target_level_code = :targetLevelCode,
                                content = cast(:content as jsonb),
                                owner_name = :ownerName,
                                license_name = :licenseName,
                                updated_at = :now
                            where course_id = :courseId
                              and version = :version
                              and state = 'draft'
                            """)
                    .param("sourceLanguage", draft.sourceLanguage())
                    .param("targetLanguage", draft.targetLanguage())
                    .param("locale", draft.locale())
                    .param("compatibilityVersion", draft.compatibilityVersion())
                    .param("frameworkCode", draft.proficiency().frameworkCode())
                    .param("frameworkVersion", draft.proficiency().frameworkVersion())
                    .param("entryLevelCode", draft.proficiency().entryLevelCode())
                    .param("targetLevelCode", draft.proficiency().targetLevelCode())
                    .param("content", writeJson(coursePayload))
                    .param("ownerName", draft.owner())
                    .param("licenseName", draft.license())
                    .param("now", Timestamp.from(now))
                    .param("courseId", courseId)
                    .param("version", version)
                    .update();
            jdbc.sql("""
                            delete from lessons
                            where course_id = :courseId and course_version = :version
                            """)
                    .param("courseId", courseId)
                    .param("version", version)
                    .update();
            jdbc.sql("""
                            delete from course_units
                            where course_id = :courseId and course_version = :version
                            """)
                    .param("courseId", courseId)
                    .param("version", version)
                    .update();
        }

        int lessonPosition = 0;
        for (int unitIndex = 0; unitIndex < draft.units().size(); unitIndex++) {
            UnitDraft unit = draft.units().get(unitIndex);
            jdbc.sql("""
                            insert into course_units (
                                course_id, course_version, id, position, content
                            ) values (
                                :courseId, :version, :unitId, :position,
                                cast(:content as jsonb)
                            )
                            """)
                    .param("courseId", courseId)
                    .param("version", version)
                    .param("unitId", unit.id())
                    .param("position", unitIndex + 1)
                    .param("content", writeJson(Map.of("id", unit.id(), "title", unit.title())))
                    .update();
            for (LessonDraft lesson : unit.lessons()) {
                lessonPosition++;
                Map<String, Object> authoring = authoringLesson(courseId, version, unit.id(), lesson);
                Map<String, Object> delivery = learnerLesson(authoring);
                jdbc.sql("""
                                insert into lessons (
                                    id, version, course_id, position, status, content,
                                    course_version, unit_id, locale,
                                    compatibility_version, learner_content
                                ) values (
                                    :lessonId, :version, :courseId, :position, 'draft',
                                    cast(:authoring as jsonb), :version, :unitId,
                                    :locale, :compatibilityVersion,
                                    cast(:delivery as jsonb)
                                )
                                """)
                        .param("lessonId", lesson.id())
                        .param("version", version)
                        .param("courseId", courseId)
                        .param("position", lessonPosition)
                        .param("authoring", writeJson(authoring))
                        .param("unitId", unit.id())
                        .param("locale", lesson.locale())
                        .param("compatibilityVersion", draft.compatibilityVersion())
                        .param("delivery", writeJson(delivery))
                        .update();
            }
        }
        audit(actor, courseId, version, existing == null ? "DRAFT_CREATED" : "DRAFT_REPLACED", Map.of());
        return requireVersion(courseId, version);
    }

    @Transactional(readOnly = true)
    public ContentVersion authoringVersion(String courseId, int version) {
        ContentVersion contentVersion = requireVersion(courseId, version);
        List<Map<String, Object>> units = jdbc.sql("""
                        select content::text
                        from course_units
                        where course_id = :courseId and course_version = :version
                        order by position
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(String.class)
                .list()
                .stream()
                .map(this::readMap)
                .toList();
        List<Map<String, Object>> lessons = jdbc.sql("""
                        select content::text
                        from lessons
                        where course_id = :courseId and course_version = :version
                        order by position
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(String.class)
                .list()
                .stream()
                .map(this::readMap)
                .toList();
        return contentVersion.withContent(Map.of(
                "course", contentVersion.content(),
                "units", units,
                "lessons", lessons));
    }

    @Transactional
    public ContentVersion transition(
            Jwt actor, String courseId, int version, ContentTransition transition) {
        ContentVersion current = requireVersion(courseId, version);
        ContentState target = ContentState.fromApi(transition.targetState());
        Instant now = clock.instant();
        ensureTransition(current.state(), target, transition.effectiveAt(), now);
        if (target == ContentState.REVIEW) {
            validateStoredDraft(courseId, version);
            validateReviewEvidence(transition.reviewEvidence());
        }
        if (target == ContentState.PUBLISHED) {
            publishVersion(courseId, version, transition.effectiveAt(), now);
        } else {
            Timestamp effectiveAt = target == ContentState.SCHEDULED
                    ? Timestamp.from(transition.effectiveAt())
                    : null;
            jdbc.sql("""
                            update course_versions
                            set state = :state,
                                effective_at = coalesce(:effectiveAt, effective_at),
                                retired_at = case when :state = 'retired' then :now else retired_at end,
                                updated_at = :now
                            where course_id = :courseId and version = :version
                            """)
                    .param("state", target.value)
                    .param("effectiveAt", effectiveAt)
                    .param("now", Timestamp.from(now))
                    .param("courseId", courseId)
                    .param("version", version)
                    .update();
            jdbc.sql("""
                            update lessons
                            set status = :state,
                                effective_at = coalesce(:effectiveAt, effective_at),
                                retired_at = case when :state = 'retired' then :now else retired_at end
                            where course_id = :courseId and course_version = :version
                            """)
                    .param("state", target.value)
                    .param("effectiveAt", effectiveAt)
                    .param("now", Timestamp.from(now))
                    .param("courseId", courseId)
                    .param("version", version)
                    .update();
            if (target == ContentState.RETIRED) {
                refreshCoursePublishedFlag(courseId);
            }
        }
        Map<String, Object> auditDetails = new LinkedHashMap<>();
        auditDetails.put("from", current.state().value);
        auditDetails.put("to", target.value);
        if (target == ContentState.REVIEW) {
            auditDetails.put("reviewEvidence", transition.reviewEvidence());
        }
        audit(actor, courseId, version, "STATE_CHANGED", auditDetails);
        return requireVersion(courseId, version);
    }

    @Transactional
    public ContentVersion rollback(Jwt actor, String courseId, int targetVersion) {
        ContentVersion target = requireVersion(courseId, targetVersion);
        if (target.state() != ContentState.RETIRED) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "ROLLBACK_TARGET_INVALID",
                    "Rollback requires a previously published and retired version.");
        }
        ContentVersion current = publishedVersion(courseId);
        Instant now = clock.instant();
        if (current != null) {
            retireVersion(courseId, current.version(), now);
        }
        publishVersion(courseId, targetVersion, now, now);
        audit(actor, courseId, targetVersion, "ROLLBACK_PUBLISHED", Map.of(
                "replacedVersion", current == null ? "none" : current.version()));
        return requireVersion(courseId, targetVersion);
    }

    @Transactional
    public boolean publishNextDueVersion() {
        CourseVersionKey due = jdbc.sql("""
                        select course_id, version
                        from course_versions
                        where state = 'scheduled' and effective_at <= :now
                        order by effective_at, course_id, version
                        for update skip locked
                        limit 1
                        """)
                .param("now", Timestamp.from(clock.instant()))
                .query((rs, rowNum) ->
                        new CourseVersionKey(rs.getString("course_id"), rs.getInt("version")))
                .optional()
                .orElse(null);
        if (due == null) {
            return false;
        }
        Instant now = clock.instant();
        publishVersion(due.courseId(), due.version(), now, now);
        auditSystem(due.courseId(), due.version(), "SCHEDULED_VERSION_PUBLISHED", Map.of());
        return true;
    }

    private void publishVersion(String courseId, int version, Instant effectiveAt, Instant now) {
        lockCourse(courseId);
        ContentVersion current = publishedVersion(courseId);
        if (current != null && current.version() != version) {
            retireVersion(courseId, current.version(), now);
        }
        jdbc.sql("""
                        update course_versions
                        set state = 'published',
                            effective_at = :effectiveAt,
                            published_at = :now,
                            retired_at = null,
                            updated_at = :now
                        where course_id = :courseId and version = :version
                        """)
                .param("effectiveAt", Timestamp.from(effectiveAt == null ? now : effectiveAt))
                .param("now", Timestamp.from(now))
                .param("courseId", courseId)
                .param("version", version)
                .update();
        jdbc.sql("""
                        update lessons
                        set status = 'published',
                            effective_at = :effectiveAt,
                            retired_at = null
                        where course_id = :courseId and course_version = :version
                        """)
                .param("effectiveAt", Timestamp.from(effectiveAt == null ? now : effectiveAt))
                .param("courseId", courseId)
                .param("version", version)
                .update();
        Map<String, Object> payload = requireVersion(courseId, version).content();
        jdbc.sql("""
                        update courses
                        set published = true, payload = cast(:payload as jsonb)
                        where id = :courseId
                        """)
                .param("payload", writeJson(payload))
                .param("courseId", courseId)
                .update();
    }

    private void retireVersion(String courseId, int version, Instant now) {
        jdbc.sql("""
                        update course_versions
                        set state = 'retired', retired_at = :now, updated_at = :now
                        where course_id = :courseId and version = :version
                        """)
                .param("now", Timestamp.from(now))
                .param("courseId", courseId)
                .param("version", version)
                .update();
        jdbc.sql("""
                        update lessons
                        set status = 'retired', retired_at = :now
                        where course_id = :courseId and course_version = :version
                        """)
                .param("now", Timestamp.from(now))
                .param("courseId", courseId)
                .param("version", version)
                .update();
    }

    private void refreshCoursePublishedFlag(String courseId) {
        jdbc.sql("""
                        update courses
                        set published = exists(
                            select 1 from course_versions
                            where course_id = :courseId and state = 'published'
                        )
                        where id = :courseId
                        """)
                .param("courseId", courseId)
                .update();
    }

    private void lockCourse(String courseId) {
        jdbc.sql("select id from courses where id = :courseId for update")
                .param("courseId", courseId)
                .query(String.class)
                .single();
    }

    private void validateDraft(String courseId, int version, CourseVersionDraft draft) {
        if (!identifier(courseId) || version < 1 || draft.compatibilityVersion() < 1) {
            invalid("Content identifiers and versions must be valid.");
        }
        ensureLanguageExists(draft.sourceLanguage());
        ensureLanguageExists(draft.targetLanguage());
        ensureProficiencyExists(draft.targetLanguage(), draft.proficiency());
        requireLocalized(draft.title(), draft.locale(), "course title");
        requireLocalized(draft.description(), draft.locale(), "course description");
        if (blank(draft.owner()) || blank(draft.license()) || draft.units() == null || draft.units().isEmpty()) {
            invalid("Owner, license, and at least one unit are required.");
        }
        Set<String> unitIds = new HashSet<>();
        Set<String> lessonIds = new HashSet<>();
        Set<String> exerciseIds = new HashSet<>();
        for (UnitDraft unit : draft.units()) {
            if (!identifier(unit.id()) || !unitIds.add(unit.id())) {
                invalid("Unit identifiers must be valid and unique.");
            }
            requireLocalized(unit.title(), draft.locale(), "unit title");
            if (unit.lessons() == null || unit.lessons().isEmpty()) {
                invalid("Every unit must contain at least one lesson.");
            }
            for (LessonDraft lesson : unit.lessons()) {
                if (!identifier(lesson.id()) || !lessonIds.add(lesson.id())) {
                    invalid("Lesson identifiers must be valid and unique.");
                }
                boolean usedByAnotherVersion = jdbc.sql("""
                                select exists(
                                    select 1 from lessons
                                    where id = :lessonId
                                      and course_id <> :courseId
                                )
                                """)
                        .param("lessonId", lesson.id())
                        .param("courseId", courseId)
                        .query(Boolean.class)
                        .single();
                if (usedByAnotherVersion) {
                    invalid("A lesson identifier cannot be reused by another course version.");
                }
                requireLocalized(lesson.title(), lesson.locale(), "lesson title");
                if (lesson.objectives() == null || lesson.objectives().isEmpty()
                        || lesson.estimatedMinutes() < 1 || lesson.estimatedMinutes() > 120
                        || lesson.exercises() == null || lesson.exercises().isEmpty()) {
                    invalid("Every lesson needs objectives, duration, and exercises.");
                }
                for (Map<String, String> objective : lesson.objectives()) {
                    requireLocalized(objective, lesson.locale(), "lesson objective");
                }
                for (ExerciseDraft exercise : lesson.exercises()) {
                    validateExercise(exercise, lesson.locale(), exerciseIds);
                }
                validateAdvancedActivities(lesson);
            }
        }
    }

    private void validateAdvancedActivities(LessonDraft lesson) {
        if (lesson.advancedActivities() == null) return;
        Set<String> mediaIds = lesson.exercises().stream()
                .filter(exercise -> exercise.media() != null)
                .map(exercise -> exercise.media().id())
                .collect(java.util.stream.Collectors.toSet());
        Set<String> activityIds = new HashSet<>();
        for (Map<String, Object> activity : lesson.advancedActivities()) {
            String id = String.valueOf(activity.get("id"));
            String mediaId = String.valueOf(activity.get("mediaId"));
            if (!identifier(id)
                    || !activityIds.add(id)
                    || !validActivityText(activity.get("contentRef"))
                    || !validActivityText(activity.get("expectedText"))
                    || !validActivityText(activity.get("targetLocale"))
                    || !validActivityText(activity.get("feedbackLocale"))
                    || !mediaIds.contains(mediaId)) {
                invalid("Advanced activity definitions need unique IDs, valid text/locales, and lesson media references.");
            }
        }
    }

    private boolean validActivityText(Object value) {
        return value instanceof String text && !blank(text);
    }

    private void validateExercise(
            ExerciseDraft exercise, String locale, Set<String> exerciseIds) {
        if (!identifier(exercise.id()) || !exerciseIds.add(exercise.id())) {
            invalid("Exercise identifiers must be valid and unique in a course version.");
        }
        requireLocalized(exercise.prompt(), locale, "exercise prompt");
        requireLocalized(exercise.explanation(), locale, "exercise explanation");
        if (!SKILLS.contains(exercise.skill())
                || exercise.conceptIds() == null
                || exercise.conceptIds().isEmpty()
                || exercise.conceptIds().stream().anyMatch(id -> !identifier(id))) {
            invalid("Exercise skill and concept references must be valid.");
        }
        if (Set.of("multiple_choice", "listen_select", "comprehension").contains(exercise.type())) {
            if (exercise.options() == null || exercise.options().size() < 2
                    || blank(exercise.correctOptionId())
                    || exercise.correctAnswer() != null) {
                invalid("Option scoring requires options and correctOptionId.");
            }
            Set<String> optionIds = new HashSet<>();
            for (ExerciseOptionDraft option : exercise.options()) {
                if (!identifier(option.id()) || !optionIds.add(option.id())) {
                    invalid("Option identifiers must be valid and unique.");
                }
                requireLocalized(option.text(), locale, "option text");
            }
            if (!optionIds.contains(exercise.correctOptionId())) {
                invalid("correctOptionId must reference an option in the exercise.");
            }
        } else if ("true_false".equals(exercise.type())) {
            if (exercise.correctAnswer() == null
                    || exercise.correctOptionId() != null
                    || (exercise.options() != null && !exercise.options().isEmpty())) {
                invalid("True/false scoring requires correctAnswer and no options.");
            }
        } else if ("flashcard".equals(exercise.type())) {
            // A flashcard records learner self-assessment and has no canonical wrong answer.
        } else if ("matching".equals(exercise.type())) {
            validateMatching(exercise, locale);
        } else if ("ordering".equals(exercise.type())) {
            validateOrdering(exercise, locale);
        } else if (Set.of("fill_blank", "dictation").contains(exercise.type())) {
            if (exercise.acceptedAnswers() == null
                    || exercise.acceptedAnswers().isEmpty()
                    || exercise.acceptedAnswers().stream().anyMatch(CurriculumContentAdminService::blank)) {
                invalid("Text scoring requires at least one accepted answer.");
            }
        } else {
            invalid("Unsupported Exercise Engine V2 type.");
        }
        if (exercise.media() != null) {
            if (!identifier(exercise.media().id())
                    || !Set.of("audio", "image").contains(exercise.media().type())
                    || blank(exercise.media().objectKey())
                    || blank(exercise.media().checksum())
                    || blank(exercise.media().locale())) {
                invalid("Media metadata must identify an object, checksum, type, and locale.");
            }
        }
    }

    private void validateStoredDraft(String courseId, int version) {
        int unitCount = jdbc.sql("""
                        select count(*) from course_units
                        where course_id = :courseId and course_version = :version
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(Integer.class)
                .single();
        int lessonCount = jdbc.sql("""
                        select count(*) from lessons
                        where course_id = :courseId and course_version = :version
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query(Integer.class)
                .single();
        if (unitCount == 0 || lessonCount == 0) {
            invalid("A publishable version requires units and lessons.");
        }
    }

    private void validateMatching(ExerciseDraft exercise, String locale) {
        if (exercise.leftItems() == null || exercise.leftItems().size() < 2
                || exercise.rightItems() == null || exercise.rightItems().size() < 2
                || exercise.correctPairs() == null
                || exercise.correctPairs().size() != exercise.leftItems().size()) {
            invalid("Matching requires two item sets and one canonical pair per left item.");
        }
        Set<String> leftIds = validateItems(exercise.leftItems(), locale);
        Set<String> rightIds = validateItems(exercise.rightItems(), locale);
        if (exercise.correctPairs().stream()
                .anyMatch(pair -> !leftIds.contains(pair.leftId()) || !rightIds.contains(pair.rightId()))) {
            invalid("Matching pairs must reference the exercise item sets.");
        }
    }

    private void validateOrdering(ExerciseDraft exercise, String locale) {
        if (exercise.items() == null || exercise.items().size() < 2
                || exercise.correctOrder() == null
                || exercise.correctOrder().size() != exercise.items().size()) {
            invalid("Ordering requires items and a complete canonical order.");
        }
        Set<String> itemIds = validateItems(exercise.items(), locale);
        if (!itemIds.equals(new HashSet<>(exercise.correctOrder()))) {
            invalid("Ordering answer must contain every item exactly once.");
        }
    }

    private Set<String> validateItems(List<ExerciseOptionDraft> items, String locale) {
        Set<String> ids = new HashSet<>();
        for (ExerciseOptionDraft item : items) {
            if (!identifier(item.id()) || !ids.add(item.id())) {
                invalid("Exercise item identifiers must be valid and unique.");
            }
            requireLocalized(item.text(), locale, "exercise item text");
        }
        return ids;
    }

    private void validateReviewEvidence(ReviewEvidence reviewEvidence) {
        if (reviewEvidence == null
                || blank(reviewEvidence.checklistVersion())
                || reviewEvidence.checklistVersion().length() > 40
                || reviewEvidence.checks() == null) {
            invalid("Review requires a versioned checklist with audit evidence.");
        }
        Set<String> checkIds = new HashSet<>();
        for (ReviewCheck check : reviewEvidence.checks()) {
            if (check == null
                    || !identifier(check.id())
                    || !checkIds.add(check.id())
                    || !check.passed()
                    || blank(check.evidence())
                    || check.evidence().length() > 500) {
                invalid("Every review check must be unique, passed, and include actionable evidence.");
            }
        }
        if (!checkIds.containsAll(REQUIRED_REVIEW_CHECKS)) {
            invalid("Review evidence is missing one or more required content checks.");
        }
    }

    private void ensureTransition(
            ContentState current, ContentState target, Instant effectiveAt, Instant now) {
        boolean allowed = switch (current) {
            case DRAFT -> target == ContentState.REVIEW;
            case REVIEW -> target == ContentState.APPROVED || target == ContentState.DRAFT;
            case APPROVED -> target == ContentState.SCHEDULED || target == ContentState.PUBLISHED;
            case SCHEDULED -> target == ContentState.PUBLISHED || target == ContentState.APPROVED;
            case PUBLISHED -> target == ContentState.RETIRED;
            case RETIRED -> false;
        };
        if (!allowed) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONTENT_TRANSITION_INVALID",
                    "The requested content lifecycle transition is invalid.");
        }
        if (target == ContentState.SCHEDULED
                && (effectiveAt == null || !effectiveAt.isAfter(now))) {
            invalid("A scheduled publication requires a future effectiveAt.");
        }
        if (target == ContentState.PUBLISHED
                && effectiveAt != null
                && effectiveAt.isAfter(now)) {
            invalid("Use the scheduled state for a future effectiveAt.");
        }
    }

    private Map<String, Object> coursePayload(
            String courseId, int version, CourseVersionDraft draft) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("id", courseId);
        payload.put("version", version);
        payload.put("sourceLanguage", draft.sourceLanguage());
        payload.put("targetLanguage", draft.targetLanguage());
        payload.put("proficiency", draft.proficiency());
        payload.put("locale", draft.locale());
        payload.put("title", draft.title());
        payload.put("description", draft.description());
        payload.put("unitIds", draft.units().stream().map(UnitDraft::id).toList());
        payload.put("compatibilityVersion", draft.compatibilityVersion());
        payload.put("owner", draft.owner());
        payload.put("license", draft.license());
        return payload;
    }

    private Map<String, Object> authoringLesson(
            String courseId, int version, String unitId, LessonDraft lesson) {
        Map<String, Object> content = new LinkedHashMap<>();
        content.put("id", lesson.id());
        content.put("courseId", courseId);
        content.put("courseVersion", version);
        content.put("unitId", unitId);
        content.put("locale", lesson.locale());
        content.put("title", lesson.title());
        content.put("objectives", lesson.objectives());
        content.put("estimatedMinutes", lesson.estimatedMinutes());
        content.put("exercises", lesson.exercises());
        content.put("advancedActivities", lesson.advancedActivities() == null
                ? List.of()
                : lesson.advancedActivities());
        return objectMapper.convertValue(content, MAP_TYPE);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> learnerLesson(Map<String, Object> authoring) {
        Map<String, Object> delivery = objectMapper.convertValue(authoring, MAP_TYPE);
        List<Map<String, Object>> exercises =
                (List<Map<String, Object>>) delivery.get("exercises");
        exercises.forEach(exercise -> {
            exercise.remove("correctOptionId");
            exercise.remove("correctAnswer");
            exercise.remove("correctPairs");
            exercise.remove("correctOrder");
            exercise.remove("acceptedAnswers");
            exercise.remove("caseSensitive");
            exercise.remove("explanation");
            if ("true_false".equals(exercise.get("type"))) {
                @SuppressWarnings("unchecked")
                Map<String, String> prompt = (Map<String, String>) exercise.get("prompt");
                Map<String, String> trueText = new LinkedHashMap<>();
                Map<String, String> falseText = new LinkedHashMap<>();
                prompt.keySet().forEach(locale -> {
                    trueText.put(locale, "vi".equals(locale) ? "Đúng" : "True");
                    falseText.put(locale, "vi".equals(locale) ? "Sai" : "False");
                });
                exercise.put(
                        "options",
                        List.of(
                                Map.of("id", "true", "text", trueText),
                                Map.of("id", "false", "text", falseText)));
            }
        });
        return delivery;
    }

    private ContentVersion requireVersion(String courseId, int version) {
        ContentVersion result = findVersion(courseId, version);
        if (result == null) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND,
                    "CONTENT_VERSION_NOT_FOUND",
                    "The requested course version was not found.");
        }
        return result;
    }

    private ContentVersion findVersion(String courseId, int version) {
        return jdbc.sql("""
                        select course_id, version, state, compatibility_version,
                               effective_at, published_at, retired_at, content::text
                        from course_versions
                        where course_id = :courseId and version = :version
                        """)
                .param("courseId", courseId)
                .param("version", version)
                .query((rs, rowNum) -> new ContentVersion(
                        rs.getString("course_id"),
                        rs.getInt("version"),
                        ContentState.fromValue(rs.getString("state")),
                        rs.getInt("compatibility_version"),
                        instant(rs.getTimestamp("effective_at")),
                        instant(rs.getTimestamp("published_at")),
                        instant(rs.getTimestamp("retired_at")),
                        readMap(rs.getString("content"))))
                .optional()
                .orElse(null);
    }

    private ContentVersion publishedVersion(String courseId) {
        return jdbc.sql("""
                        select course_id, version, state, compatibility_version,
                               effective_at, published_at, retired_at, content::text
                        from course_versions
                        where course_id = :courseId and state = 'published'
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> new ContentVersion(
                        rs.getString("course_id"),
                        rs.getInt("version"),
                        ContentState.fromValue(rs.getString("state")),
                        rs.getInt("compatibility_version"),
                        instant(rs.getTimestamp("effective_at")),
                        instant(rs.getTimestamp("published_at")),
                        instant(rs.getTimestamp("retired_at")),
                        readMap(rs.getString("content"))))
                .optional()
                .orElse(null);
    }

    private void ensureLanguageExists(String languageTag) {
        boolean exists = jdbc.sql("""
                        select exists(
                            select 1 from learning_languages
                            where language_tag = :languageTag and enabled = true
                        )
                        """)
                .param("languageTag", languageTag)
                .query(Boolean.class)
                .single();
        if (!exists) {
            invalid("The content references an unavailable language.");
        }
    }

    private void ensureProficiencyExists(
            String targetLanguage, CourseProficiency proficiency) {
        if (proficiency == null
                || blank(proficiency.frameworkCode())
                || blank(proficiency.frameworkVersion())
                || blank(proficiency.entryLevelCode())
                || blank(proficiency.targetLevelCode())) {
            invalid("A versioned proficiency framework with entry and target levels is required.");
        }
        boolean exists = jdbc.sql("""
                        select exists(
                            select 1
                            from proficiency_frameworks framework
                            join proficiency_levels entry_level
                              on entry_level.framework_code = framework.code
                             and entry_level.framework_version = framework.version
                             and entry_level.code = :entryLevelCode
                            join proficiency_levels target_level
                              on target_level.framework_code = framework.code
                             and target_level.framework_version = framework.version
                             and target_level.code = :targetLevelCode
                            where framework.code = :frameworkCode
                              and framework.version = :frameworkVersion
                              and (framework.applies_to_language is null
                                   or framework.applies_to_language = :targetLanguage)
                              and entry_level.ordinal <= target_level.ordinal
                        )
                        """)
                .param("entryLevelCode", proficiency.entryLevelCode())
                .param("targetLevelCode", proficiency.targetLevelCode())
                .param("frameworkCode", proficiency.frameworkCode())
                .param("frameworkVersion", proficiency.frameworkVersion())
                .param("targetLanguage", targetLanguage)
                .query(Boolean.class)
                .single();
        if (!exists) {
            invalid("The course references an unavailable or invalid proficiency range.");
        }
    }

    private void requireLocalized(Map<String, String> value, String locale, String field) {
        if (value == null || blank(value.get(locale))) {
            invalid("Missing " + field + " for locale " + locale + ".");
        }
    }

    private void audit(
            Jwt actor, String courseId, int version, String action, Map<String, Object> details) {
        String issuer = actor.getIssuer() == null ? "" : actor.getIssuer().toString();
        insertAudit(hash(issuer + "\0" + actor.getSubject()), courseId, version, action, details);
    }

    private void auditSystem(
            String courseId, int version, String action, Map<String, Object> details) {
        insertAudit(hash("system\0content-publisher"), courseId, version, action, details);
    }

    private void insertAudit(
            String actorHash,
            String courseId,
            int version,
            String action,
            Map<String, Object> details) {
        jdbc.sql("""
                        insert into content_audit_events (
                            id, course_id, course_version, actor_subject_hash,
                            action, occurred_at, details
                        ) values (
                            :id, :courseId, :version, :actorHash,
                            :action, :occurredAt, cast(:details as jsonb)
                        )
                        """)
                .param("id", UUID.randomUUID())
                .param("courseId", courseId)
                .param("version", version)
                .param("actorHash", actorHash)
                .param("action", action)
                .param("occurredAt", Timestamp.from(clock.instant()))
                .param("details", writeJson(details))
                .update();
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Could not serialize content.", exception);
        }
    }

    private Map<String, Object> readMap(String json) {
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored content is not valid JSON.", exception);
        }
    }

    private static Instant instant(Timestamp value) {
        return value == null ? null : value.toInstant();
    }

    private static boolean identifier(String value) {
        return value != null && value.matches("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$");
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }

    private static void invalid(String detail) {
        throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "CONTENT_INVALID", detail);
    }

    private static String hash(String value) {
        try {
            return java.util.HexFormat.of()
                    .formatHex(MessageDigest.getInstance("SHA-256")
                            .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable.", exception);
        }
    }

    public enum ContentState {
        DRAFT("draft"),
        REVIEW("review"),
        APPROVED("approved"),
        SCHEDULED("scheduled"),
        PUBLISHED("published"),
        RETIRED("retired");

        private final String value;

        ContentState(String value) {
            this.value = value;
        }

        static ContentState fromApi(String value) {
            return fromValue(value);
        }

        static ContentState fromValue(String value) {
            for (ContentState state : values()) {
                if (state.value.equals(value)) {
                    return state;
                }
            }
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "CONTENT_STATE_INVALID",
                    "The requested content state is invalid.");
        }

        @JsonValue
        public String value() {
            return value;
        }
    }

    public record CourseVersionDraft(
            String sourceLanguage,
            String targetLanguage,
            String locale,
            int compatibilityVersion,
            CourseProficiency proficiency,
            Map<String, String> title,
            Map<String, String> description,
            String owner,
            String license,
            List<UnitDraft> units) {}

    public record CourseProficiency(
            String frameworkCode,
            String frameworkVersion,
            String entryLevelCode,
            String targetLevelCode) {}

    public record UnitDraft(String id, Map<String, String> title, List<LessonDraft> lessons) {}

    public record LessonDraft(
            String id,
            String locale,
            Map<String, String> title,
            List<Map<String, String>> objectives,
            int estimatedMinutes,
            List<ExerciseDraft> exercises,
            List<Map<String, Object>> advancedActivities) {}

    public record ExerciseDraft(
            String id,
            String type,
            Map<String, String> prompt,
            List<ExerciseOptionDraft> options,
            String correctOptionId,
            Boolean correctAnswer,
            Map<String, String> explanation,
            String skill,
            List<String> conceptIds,
            MediaMetadata media,
            List<ExerciseOptionDraft> items,
            List<ExerciseOptionDraft> leftItems,
            List<ExerciseOptionDraft> rightItems,
            List<ExercisePairDraft> correctPairs,
            List<String> correctOrder,
            List<String> acceptedAnswers,
            Boolean caseSensitive,
            Map<String, String> instruction,
            Map<String, String> hint,
            Map<String, String> transcript) {}

    public record ExerciseOptionDraft(String id, Map<String, String> text) {}

    public record ExercisePairDraft(String leftId, String rightId) {}

    public record MediaMetadata(
            String id,
            String type,
            String objectKey,
            String checksum,
            String locale,
            Integer durationMs,
            Map<String, String> altText) {}

    public record ContentTransition(
            String targetState, Instant effectiveAt, ReviewEvidence reviewEvidence) {}

    public record ReviewEvidence(String checklistVersion, List<ReviewCheck> checks) {}

    public record ReviewCheck(String id, boolean passed, String evidence) {}

    public record ContentVersion(
            String courseId,
            int version,
            ContentState state,
            int compatibilityVersion,
            Instant effectiveAt,
            Instant publishedAt,
            Instant retiredAt,
            Map<String, Object> content) {

        ContentVersion withContent(Map<String, Object> replacement) {
            return new ContentVersion(
                    courseId,
                    version,
                    state,
                    compatibilityVersion,
                    effectiveAt,
                    publishedAt,
                    retiredAt,
                    replacement);
        }
    }

    private record CourseVersionKey(String courseId, int version) {}
}

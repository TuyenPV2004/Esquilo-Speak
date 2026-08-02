package com.esquilospeak.curriculumcontent;

import com.esquilospeak.ApiException;
import java.util.List;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.LinkedHashMap;
import java.text.Normalizer;
import java.util.function.BiFunction;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

@Service
public class CurriculumContentService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final JdbcClient jdbc;
    private final ObjectMapper objectMapper;
    private final Map<String, BiFunction<Map<String, Object>, Map<String, Object>, ScoredResponse>> scorers;

    public CurriculumContentService(JdbcClient jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        Map<String, BiFunction<Map<String, Object>, Map<String, Object>, ScoredResponse>> registered =
                new LinkedHashMap<>();
        registered.put("multiple_choice", this::scoreMultipleChoice);
        registered.put("true_false", this::scoreTrueFalse);
        registered.put("flashcard", this::scoreFlashcard);
        registered.put("matching", this::scoreMatching);
        registered.put("listen_select", this::scoreMultipleChoice);
        registered.put("ordering", this::scoreOrdering);
        registered.put("fill_blank", this::scoreText);
        registered.put("dictation", this::scoreText);
        registered.put("comprehension", this::scoreMultipleChoice);
        this.scorers = Map.copyOf(registered);
    }

    public List<Map<String, Object>> listLanguages() {
        return jdbc.sql("select payload::text from learning_languages where enabled = true order by id")
                .query(String.class)
                .list()
                .stream()
                .map(this::readMap)
                .toList();
    }

    public List<Map<String, Object>> listCourses(String sourceLanguage, String targetLanguage) {
        return jdbc.sql("""
                        select version_content.content::text
                        from course_versions version_content
                        where source_language = :sourceLanguage
                          and target_language = :targetLanguage
                          and state = 'published'
                          and (effective_at is null or effective_at <= now())
                        order by course_id
                        """)
                .param("sourceLanguage", sourceLanguage)
                .param("targetLanguage", targetLanguage)
                .query(String.class)
                .list()
                .stream()
                .map(this::readMap)
                .toList();
    }

    public List<Map<String, Object>> listLessonSummaries(String courseId) {
        ensureCourseExists(courseId);
        return jdbc.sql("""
                        select lesson.id, lesson.version, lesson.position,
                               lesson.unit_id, lesson.learner_content::text as content,
                               course_unit.content::text as unit_content
                        from lessons lesson
                        join course_versions course_version
                          on course_version.course_id = lesson.course_id
                         and course_version.version = lesson.course_version
                        join course_units course_unit
                          on course_unit.course_id = lesson.course_id
                         and course_unit.course_version = lesson.course_version
                         and course_unit.id = lesson.unit_id
                        where lesson.course_id = :courseId
                          and course_version.state = 'published'
                          and lesson.status = 'published'
                          and (course_version.effective_at is null
                               or course_version.effective_at <= now())
                        order by lesson.position
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) -> {
                    Map<String, Object> lesson = readMap(rs.getString("content"));
                    Map<String, Object> unit = readMap(rs.getString("unit_content"));
                    Map<String, Object> summary = new LinkedHashMap<>();
                    summary.put("id", rs.getString("id"));
                    summary.put("version", rs.getInt("version"));
                    summary.put("locale", lesson.get("locale"));
                    summary.put("title", lesson.get("title"));
                    summary.put("estimatedMinutes", lesson.get("estimatedMinutes"));
                    summary.put("unitId", rs.getString("unit_id"));
                    summary.put("unitTitle", unit.get("title"));
                    if (unit.containsKey("guidebook")) {
                        summary.put("unitGuidebook", unit.get("guidebook"));
                    }
                    summary.put("position", rs.getInt("position"));
                    return summary;
                })
                .list();
    }

    public List<Map<String, Object>> listAdvancedActivities(String courseId) {
        ensureCourseExists(courseId);
        return jdbc.sql("""
                        select activity.value::text as content
                        from lessons lesson
                        join course_versions course_version
                          on course_version.course_id = lesson.course_id
                         and course_version.version = lesson.course_version
                        cross join lateral jsonb_array_elements(
                          coalesce(lesson.learner_content->'advancedActivities', '[]'::jsonb)
                        ) activity(value)
                        where lesson.course_id = :courseId
                          and lesson.status = 'published'
                          and course_version.state = 'published'
                          and (course_version.effective_at is null
                               or course_version.effective_at <= now())
                        order by lesson.position, activity.value->>'id'
                        """)
                .param("courseId", courseId)
                .query(String.class)
                .list()
                .stream()
                .map(this::readMap)
                .toList();
    }

    public LearnerLesson learnerLesson(String lessonId, Integer requestedVersion) {
        String sql = requestedVersion == null
                ? """
                  select lesson.version, lesson.learner_content::text as content
                  from lessons lesson
                  join course_versions course_version
                    on course_version.course_id = lesson.course_id
                   and course_version.version = lesson.course_version
                  where lesson.id = :lessonId
                    and lesson.status = 'published'
                    and course_version.state = 'published'
                    and (course_version.effective_at is null
                         or course_version.effective_at <= now())
                  order by lesson.version desc
                  limit 1
                  """
                : """
                  select lesson.version, lesson.learner_content::text as content
                  from lessons lesson
                  join course_versions course_version
                    on course_version.course_id = lesson.course_id
                   and course_version.version = lesson.course_version
                  where lesson.id = :lessonId
                    and lesson.version = :version
                    and lesson.status = 'published'
                    and course_version.state = 'published'
                    and (course_version.effective_at is null
                         or course_version.effective_at <= now())
                  """;
        JdbcClient.StatementSpec statement = jdbc.sql(sql).param("lessonId", lessonId);
        if (requestedVersion != null) {
            statement = statement.param("version", requestedVersion);
        }
        return statement.query((rs, rowNum) -> {
                    int version = rs.getInt("version");
                    ObjectNode content = readObject(rs.getString("content"));
                    content.put("version", version);
                    return new LearnerLesson(
                            objectMapper.convertValue(content, MAP_TYPE),
                            "\"" + lessonId + "-" + version + "\"");
                })
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "LESSON_NOT_FOUND", "The requested lesson was not found."));
    }

    public ExerciseAnswer exerciseAnswer(
            String courseId,
            String lessonId,
            int lessonVersion,
            String exerciseId,
            Map<String, Object> response) {
        Map<String, Object> lesson = jdbc.sql("""
                        select content::text
                        from lessons
                        where id = :lessonId
                          and version = :version
                          and course_id = :courseId
                          and (
                              status = 'published'
                              or (
                                  status = 'retired'
                                  and compatibility_version = (
                                      select compatibility_version
                                      from course_versions
                                      where course_id = :courseId
                                        and state = 'published'
                                  )
                              )
                          )
                        """)
                .param("lessonId", lessonId)
                .param("version", lessonVersion)
                .param("courseId", courseId)
                .query(String.class)
                .optional()
                .map(this::readMap)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNPROCESSABLE_CONTENT,
                        "LESSON_VERSION_INVALID",
                        "The lesson version is not available for this course."));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> exercises = (List<Map<String, Object>>) lesson.get("exercises");
        Map<String, Object> exercise = exercises.stream()
                .filter(item -> exerciseId.equals(item.get("id")))
                .findFirst()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNPROCESSABLE_CONTENT,
                        "EXERCISE_NOT_FOUND",
                        "The exercise does not belong to the lesson."));
        String type = String.valueOf(exercise.get("type"));
        BiFunction<Map<String, Object>, Map<String, Object>, ScoredResponse> scorer = scorers.get(type);
        if (scorer == null) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "EXERCISE_TYPE_UNSUPPORTED",
                    "No scorer is registered for the exercise type.");
        }
        ScoredResponse scored = scorer.apply(exercise, response);
        @SuppressWarnings("unchecked")
        Map<String, String> explanation = (Map<String, String>) exercise.get("explanation");
        @SuppressWarnings("unchecked")
        List<String> conceptIds = (List<String>) exercise.getOrDefault("conceptIds", List.of());
        return new ExerciseAnswer(
                scored.correctOptionId(),
                scored.correctResponse(),
                explanation,
                scored.correct(),
                List.copyOf(conceptIds));
    }

    private ScoredResponse scoreMultipleChoice(
            Map<String, Object> exercise, Map<String, Object> response) {
        String selectedOptionId = optionId(response);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> options = (List<Map<String, Object>>) exercise.get("options");
        boolean optionExists = options.stream()
                .anyMatch(option -> selectedOptionId.equals(option.get("id")));
        if (!optionExists) {
            throw invalidOption("The selected option does not belong to the exercise.");
        }
        String correctOptionId = (String) exercise.get("correctOptionId");
        return new ScoredResponse(
                selectedOptionId.equals(correctOptionId),
                correctOptionId,
                Map.of("kind", "option", "optionId", correctOptionId));
    }

    private ScoredResponse scoreTrueFalse(
            Map<String, Object> exercise, Map<String, Object> response) {
        String selectedOptionId;
        if ("boolean".equals(response.get("kind")) && response.get("value") instanceof Boolean value) {
            selectedOptionId = value.toString();
        } else {
            selectedOptionId = optionId(response);
        }
        if (!List.of("true", "false").contains(selectedOptionId)) {
            throw invalidOption("A true/false answer must be true or false.");
        }
        String correctOptionId = String.valueOf(exercise.get("correctAnswer"));
        return new ScoredResponse(
                selectedOptionId.equals(correctOptionId),
                correctOptionId,
                Map.of("kind", "boolean", "value", Boolean.valueOf(correctOptionId)));
    }

    private ScoredResponse scoreFlashcard(
            Map<String, Object> exercise, Map<String, Object> response) {
        Object value = response.get("value");
        if (!"self_assessment".equals(response.get("kind"))
                || !(value instanceof String assessment)
                || !Set.of("know", "learning").contains(assessment)) {
            throw invalidResponse("A flashcard response must be know or learning.");
        }
        return new ScoredResponse(true, null, Map.of("kind", "self_assessment", "value", value));
    }

    @SuppressWarnings("unchecked")
    private ScoredResponse scoreMatching(
            Map<String, Object> exercise, Map<String, Object> response) {
        if (!"pairs".equals(response.get("kind")) || !(response.get("pairs") instanceof List<?> rawPairs)) {
            throw invalidResponse("This exercise requires pair responses.");
        }
        List<Map<String, Object>> canonical = (List<Map<String, Object>>) exercise.get("correctPairs");
        List<String> expected = canonical.stream().map(this::pairKey).sorted().toList();
        List<String> actual = new ArrayList<>();
        for (Object item : rawPairs) {
            if (!(item instanceof Map<?, ?> pair)) throw invalidResponse("Every pair must be an object.");
            actual.add(pairKey((Map<String, Object>) pair));
        }
        actual.sort(Comparator.naturalOrder());
        Map<String, Object> correct = Map.of("kind", "pairs", "pairs", canonical);
        return new ScoredResponse(expected.equals(actual), null, correct);
    }

    @SuppressWarnings("unchecked")
    private ScoredResponse scoreOrdering(
            Map<String, Object> exercise, Map<String, Object> response) {
        if (!"sequence".equals(response.get("kind")) || !(response.get("itemIds") instanceof List<?> raw)) {
            throw invalidResponse("This exercise requires an ordered sequence.");
        }
        List<String> expected = (List<String>) exercise.get("correctOrder");
        List<String> actual = raw.stream().map(String::valueOf).toList();
        return new ScoredResponse(
                expected.equals(actual), null, Map.of("kind", "sequence", "itemIds", expected));
    }

    @SuppressWarnings("unchecked")
    private ScoredResponse scoreText(
            Map<String, Object> exercise, Map<String, Object> response) {
        if (!"text".equals(response.get("kind")) || !(response.get("text") instanceof String text)) {
            throw invalidResponse("This exercise requires a text response.");
        }
        boolean caseSensitive = Boolean.TRUE.equals(exercise.get("caseSensitive"));
        List<String> accepted = (List<String>) exercise.get("acceptedAnswers");
        String normalized = normalizeText(text, caseSensitive);
        boolean correct = accepted.stream()
                .map(answer -> normalizeText(answer, caseSensitive))
                .anyMatch(normalized::equals);
        return new ScoredResponse(
                correct, null, Map.of("kind", "text", "text", accepted.getFirst()));
    }

    private String pairKey(Map<String, Object> pair) {
        Object left = pair.get("leftId");
        Object right = pair.get("rightId");
        if (!(left instanceof String) || !(right instanceof String)) {
            throw invalidResponse("Every pair needs leftId and rightId.");
        }
        return left + "\u0000" + right;
    }

    private String normalizeText(String value, boolean caseSensitive) {
        String normalized = Normalizer.normalize(value, Normalizer.Form.NFKC)
                .trim()
                .replaceAll("\\s+", " ");
        return caseSensitive ? normalized : normalized.toLowerCase(Locale.ROOT);
    }

    private String optionId(Map<String, Object> response) {
        if (!"option".equals(response.get("kind")) || !(response.get("optionId") instanceof String optionId)) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "ATTEMPT_RESPONSE_INVALID",
                    "This exercise requires an option response.");
        }
        return optionId;
    }

    private ApiException invalidOption(String message) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "OPTION_NOT_FOUND", message);
    }

    private ApiException invalidResponse(String message) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "ATTEMPT_RESPONSE_INVALID", message);
    }

    public List<LessonStructure> courseStructure(String courseId) {
        ensureCourseExists(courseId);
        return jdbc.sql("""
                        select lesson.id, lesson.version,
                               jsonb_array_length(lesson.content->'exercises') as exercise_count
                        from lessons lesson
                        join course_versions course_version
                          on course_version.course_id = lesson.course_id
                         and course_version.version = lesson.course_version
                        where lesson.course_id = :courseId
                          and lesson.status = 'published'
                          and course_version.state = 'published'
                        order by lesson.position
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) ->
                        new LessonStructure(rs.getString("id"), rs.getInt("version"), rs.getInt("exercise_count")))
                .list();
    }

    private void ensureCourseExists(String courseId) {
        boolean exists = jdbc.sql("""
                        select exists(
                            select 1
                            from course_versions
                            where course_id = :courseId and state = 'published'
                              and (effective_at is null or effective_at <= now())
                        )
                        """)
                .param("courseId", courseId)
                .query(Boolean.class)
                .single();
        if (!exists) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND, "COURSE_NOT_FOUND", "The requested course was not found.");
        }
    }

    private Map<String, Object> readMap(String json) {
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored content is not valid JSON.", exception);
        }
    }

    private ObjectNode readObject(String json) {
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node instanceof ObjectNode object) {
                return object;
            }
            throw new IllegalStateException("Stored lesson content must be an object.");
        } catch (JacksonException exception) {
            throw new IllegalStateException("Stored content is not valid JSON.", exception);
        }
    }

    public record LearnerLesson(Map<String, Object> payload, String etag) {}

    public record ExerciseAnswer(
            String correctOptionId,
            Map<String, Object> correctResponse,
            Map<String, String> explanation,
            boolean correct,
            List<String> conceptIds) {}

    private record ScoredResponse(
            boolean correct,
            String correctOptionId,
            Map<String, Object> correctResponse) {}

    public record LessonStructure(String lessonId, int lessonVersion, int exerciseCount) {}
}

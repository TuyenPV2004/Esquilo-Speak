package com.esquilospeak.curriculumcontent;

import com.esquilospeak.ApiException;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;
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
                        select lesson.id, lesson.version,
                               lesson.learner_content::text as content
                        from lessons lesson
                        join course_versions course_version
                          on course_version.course_id = lesson.course_id
                         and course_version.version = lesson.course_version
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
                    return Map.of(
                            "id", rs.getString("id"),
                            "version", rs.getInt("version"),
                            "title", lesson.get("title"),
                            "estimatedMinutes", lesson.get("estimatedMinutes"));
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
        String selectedOptionId = optionId(response);
        if (!List.of("true", "false").contains(selectedOptionId)) {
            throw invalidOption("A true/false answer must be true or false.");
        }
        String correctOptionId = String.valueOf(exercise.get("correctAnswer"));
        return new ScoredResponse(
                selectedOptionId.equals(correctOptionId),
                correctOptionId,
                Map.of("kind", "option", "optionId", correctOptionId));
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

package com.esquilospeak.curriculumcontent;

import com.esquilospeak.ApiException;
import java.util.List;
import java.util.Map;
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

    public CurriculumContentService(JdbcClient jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
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
                        select payload::text
                        from courses
                        where source_language = :sourceLanguage
                          and target_language = :targetLanguage
                          and published = true
                        order by id
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
                        select id, version, content::text
                        from lessons
                        where course_id = :courseId and status = 'published'
                        order by position
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

    public LearnerLesson learnerLesson(String lessonId, Integer requestedVersion) {
        String sql = requestedVersion == null
                ? """
                  select version, content::text
                  from lessons
                  where id = :lessonId and status = 'published'
                  order by version desc
                  limit 1
                  """
                : """
                  select version, content::text
                  from lessons
                  where id = :lessonId and version = :version and status = 'published'
                  """;
        JdbcClient.StatementSpec statement = jdbc.sql(sql).param("lessonId", lessonId);
        if (requestedVersion != null) {
            statement = statement.param("version", requestedVersion);
        }
        return statement.query((rs, rowNum) -> {
                    int version = rs.getInt("version");
                    ObjectNode content = readObject(rs.getString("content"));
                    content.remove("metadata");
                    content.put("version", version);
                    content.get("exercises").forEach(exercise -> {
                        if (exercise instanceof ObjectNode object) {
                            object.remove("correctOptionId");
                            object.remove("explanation");
                        }
                    });
                    return new LearnerLesson(
                            objectMapper.convertValue(content, MAP_TYPE),
                            "\"" + lessonId + "-" + version + "\"");
                })
                .optional()
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "LESSON_NOT_FOUND", "The requested lesson was not found."));
    }

    public ExerciseAnswer exerciseAnswer(
            String courseId, String lessonId, int lessonVersion, String exerciseId, String selectedOptionId) {
        Map<String, Object> lesson = jdbc.sql("""
                        select content::text
                        from lessons
                        where id = :lessonId
                          and version = :version
                          and course_id = :courseId
                          and status = 'published'
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
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> options = (List<Map<String, Object>>) exercise.get("options");
        boolean optionExists = options.stream().anyMatch(option -> selectedOptionId.equals(option.get("id")));
        if (!optionExists) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "OPTION_NOT_FOUND",
                    "The selected option does not belong to the exercise.");
        }
        @SuppressWarnings("unchecked")
        Map<String, String> explanation = (Map<String, String>) exercise.get("explanation");
        return new ExerciseAnswer(
                (String) exercise.get("correctOptionId"),
                explanation,
                selectedOptionId.equals(exercise.get("correctOptionId")));
    }

    public List<LessonStructure> courseStructure(String courseId) {
        ensureCourseExists(courseId);
        return jdbc.sql("""
                        select id, version, jsonb_array_length(content->'exercises') as exercise_count
                        from lessons
                        where course_id = :courseId and status = 'published'
                        order by position
                        """)
                .param("courseId", courseId)
                .query((rs, rowNum) ->
                        new LessonStructure(rs.getString("id"), rs.getInt("version"), rs.getInt("exercise_count")))
                .list();
    }

    private void ensureCourseExists(String courseId) {
        boolean exists = jdbc.sql("select exists(select 1 from courses where id = :courseId and published = true)")
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
            String correctOptionId, Map<String, String> explanation, boolean correct) {}

    public record LessonStructure(String lessonId, int lessonVersion, int exerciseCount) {}
}

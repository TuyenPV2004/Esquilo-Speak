package com.esquilospeak.curriculumcontent;

import jakarta.validation.constraints.Pattern;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1")
class CurriculumContentController {

    private static final String IDENTIFIER = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$";
    private static final String LOCALE = "^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$";

    private final CurriculumContentService contentService;

    CurriculumContentController(CurriculumContentService contentService) {
        this.contentService = contentService;
    }

    @GetMapping("/languages")
    Map<String, List<Map<String, Object>>> languages() {
        return Map.of("items", contentService.listLanguages());
    }

    @GetMapping("/courses")
    Map<String, List<Map<String, Object>>> courses(
            @RequestParam @Pattern(regexp = LOCALE) String sourceLanguage,
            @RequestParam @Pattern(regexp = LOCALE) String targetLanguage) {
        return Map.of("items", contentService.listCourses(sourceLanguage, targetLanguage));
    }

    @GetMapping("/courses/{courseId}/lessons")
    Map<String, List<Map<String, Object>>> lessons(
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId) {
        return Map.of("items", contentService.listLessonSummaries(courseId));
    }

    @GetMapping("/courses/{courseId}/advanced-activities")
    Map<String, List<Map<String, Object>>> advancedActivities(
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId) {
        return Map.of("items", contentService.listAdvancedActivities(courseId));
    }

    @GetMapping("/lessons/{lessonId}")
    ResponseEntity<Map<String, Object>> lesson(
            @PathVariable @Pattern(regexp = IDENTIFIER) String lessonId,
            @RequestParam(required = false) Integer version) {
        CurriculumContentService.LearnerLesson lesson = contentService.learnerLesson(lessonId, version);
        return ResponseEntity.ok().eTag(lesson.etag()).body(lesson.payload());
    }
}

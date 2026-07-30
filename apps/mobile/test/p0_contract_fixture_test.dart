import 'dart:convert';
import 'dart:io';

import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the frozen P0 learning integration fixture', () async {
    final fixture =
        jsonDecode(
              await File(
                '../../tests/contract/fixtures/P0_Android_Integration.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final operations = fixture['operations'] as Map<String, dynamic>;

    final languages =
        (operations['listLearningLanguages']['response']['items']
                as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(LearningLanguage.fromJson)
            .toList();
    final courses =
        (operations['listCourses']['response']['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Course.fromJson)
            .toList();
    final lessons =
        (operations['listCourseLessons']['response']['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(LessonSummary.fromJson)
            .toList();
    final lesson = Lesson.fromJson(
      operations['getLesson']['response'] as Map<String, dynamic>,
    );
    final feedback = AttemptFeedback.fromJson(
      operations['submitAttempt']['response'] as Map<String, dynamic>,
    );
    final progress = CourseProgress.fromJson(
      operations['getCourseProgress']['response'] as Map<String, dynamic>,
    );

    expect(fixture['release'], 'p0-android-0.4.0');
    expect(languages.single.languageTag, 'en');
    expect(courses.single.sourceLanguage, 'vi');
    expect(lessons.single.id, lesson.id);
    expect(lesson.exercises.single.options, hasLength(2));
    expect(feedback.correct, isTrue);
    expect(feedback.progress.courseId, progress.courseId);
  });
}

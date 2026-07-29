import 'learning_models.dart';

abstract interface class LearningRepository {
  Future<List<LearningLanguage>> languages();

  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<List<LessonSummary>> lessons(String courseId);

  Future<Lesson> lesson(String lessonId, {int? version});

  Future<AttemptFeedback> submitAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required String selectedOptionId,
  });

  Future<CourseProgress> progress(String courseId);
}

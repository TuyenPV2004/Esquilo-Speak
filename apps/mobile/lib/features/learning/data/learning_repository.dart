import 'learning_models.dart';

abstract interface class LearningRepository {
  Future<List<LearningLanguage>> languages();

  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<List<LessonSummary>> lessons(String courseId);

  Future<Lesson> lesson(String lessonId, {int? version});

  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required String selectedOptionId,
  });

  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt);

  Future<CourseProgress> progress(String courseId);
}

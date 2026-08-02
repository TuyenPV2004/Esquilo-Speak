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
    required ExerciseResponse response,
  });

  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt);

  Future<CourseProgress> progress(String courseId);
}

abstract interface class LessonResumeStore {
  Future<LessonResume?> loadLessonResume(String lessonId, int version);

  Future<void> saveLessonResume(LessonResume resume);

  Future<void> clearLessonResume(String lessonId, int version);
}

abstract interface class UnitDownloadStore {
  Future<UnitDownloadStatus> unitDownloadStatus({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  });

  Future<UnitDownloadStatus> downloadUnit({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  });
}

abstract interface class CourseDownloadStore {
  Future<CourseDownloadStatus> courseDownloadStatus({
    required Course course,
    required List<LessonSummary> lessons,
  });

  Future<CourseDownloadStatus> downloadCourse({
    required Course course,
    required List<LessonSummary> lessons,
  });
}

abstract interface class PracticeHistoryStore {
  Future<List<String>> recentMistakeExerciseIds(String courseId);
}

class LessonResume {
  const LessonResume({
    required this.lessonId,
    required this.lessonVersion,
    required this.exerciseIndex,
    required this.mistakeExerciseIndexes,
    required this.reviewingMistakes,
  });

  factory LessonResume.fromJson(Map<String, dynamic> json) => LessonResume(
    lessonId: json['lessonId'] as String,
    lessonVersion: json['lessonVersion'] as int,
    exerciseIndex: json['exerciseIndex'] as int,
    mistakeExerciseIndexes: (json['mistakeExerciseIndexes'] as List<dynamic>)
        .cast<int>(),
    reviewingMistakes: json['reviewingMistakes'] as bool,
  );

  final String lessonId;
  final int lessonVersion;
  final int exerciseIndex;
  final List<int> mistakeExerciseIndexes;
  final bool reviewingMistakes;

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'lessonVersion': lessonVersion,
    'exerciseIndex': exerciseIndex,
    'mistakeExerciseIndexes': mistakeExerciseIndexes,
    'reviewingMistakes': reviewingMistakes,
  };
}

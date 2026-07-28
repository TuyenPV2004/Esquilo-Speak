import 'package:flutter/foundation.dart';

import '../data/learning_models.dart';
import '../data/learning_repository.dart';

enum LearningStep { catalog, courses, lessons, lesson, feedback, progress }

class LearningViewModel extends ChangeNotifier {
  LearningViewModel(this._repository);

  final LearningRepository _repository;

  LearningStep step = LearningStep.catalog;
  bool loading = false;
  String? error;
  String? selectionError;
  List<LearningLanguage> languages = const [];
  List<Course> courses = const [];
  List<LessonSummary> lessons = const [];
  Course? selectedCourse;
  Lesson? selectedLesson;
  String? selectedOptionId;
  AttemptFeedback? feedback;
  CourseProgress? courseProgress;

  Future<void> loadCatalog() => _run(() async {
    step = LearningStep.catalog;
    languages = await _repository.languages();
  });

  Future<void> chooseLanguage(LearningLanguage language) => _run(() async {
    step = LearningStep.courses;
    courses = await _repository.courses(
      sourceLanguage: 'vi',
      targetLanguage: language.languageTag,
    );
  });

  Future<void> chooseCourse(Course course) => _run(() async {
    selectedCourse = course;
    step = LearningStep.lessons;
    lessons = await _repository.lessons(course.id);
  });

  Future<void> chooseLesson(LessonSummary summary) => _run(() async {
    selectedLesson = await _repository.lesson(
      summary.id,
      version: summary.version,
    );
    selectedOptionId = null;
    selectionError = null;
    step = LearningStep.lesson;
  });

  void selectOption(String optionId) {
    selectedOptionId = optionId;
    selectionError = null;
    notifyListeners();
  }

  Future<void> submitAnswer() async {
    final lesson = selectedLesson;
    final optionId = selectedOptionId;
    if (lesson == null || optionId == null) {
      selectionError = 'select_answer';
      notifyListeners();
      return;
    }
    await _run(() async {
      feedback = await _repository.submitAttempt(
        lesson: lesson,
        exercise: lesson.exercises.first,
        selectedOptionId: optionId,
      );
      step = LearningStep.feedback;
    });
  }

  Future<void> showProgress() => _run(() async {
    final course = selectedCourse;
    if (course == null) return;
    courseProgress = await _repository.progress(course.id);
    step = LearningStep.progress;
  });

  Future<void> retry() async {
    switch (step) {
      case LearningStep.catalog:
        await loadCatalog();
      case LearningStep.courses:
        final target = languages.where((item) => item.languageTag == 'en');
        if (target.isNotEmpty) await chooseLanguage(target.first);
      case LearningStep.lessons:
        final course = selectedCourse;
        if (course != null) await chooseCourse(course);
      case LearningStep.lesson:
        final lesson = selectedLesson;
        if (lesson != null) {
          await chooseLesson(
            LessonSummary(
              id: lesson.id,
              version: lesson.version,
              title: lesson.title,
              estimatedMinutes: 1,
            ),
          );
        }
      case LearningStep.feedback:
        await submitAnswer();
      case LearningStep.progress:
        await showProgress();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on Object catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

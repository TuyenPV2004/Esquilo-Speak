import 'package:flutter/foundation.dart';

import '../../../core/network/user_facing_failure.dart';
import '../data/learning_models.dart';
import '../data/offline_learning_repository.dart';
import '../data/learning_repository.dart';

enum LearningStep {
  catalog,
  courses,
  lessons,
  lesson,
  queued,
  feedback,
  progress,
}

class LearningViewModel extends ChangeNotifier {
  LearningViewModel(
    this._repository, {
    required this.learningContext,
    required this.onCourseSelected,
  });

  final LearningRepository _repository;
  final LearningContextSnapshot Function() learningContext;
  final Future<void> Function(Course course) onCourseSelected;

  LearningStep step = LearningStep.catalog;
  bool loading = false;
  UserFacingFailure? error;
  String? selectionError;
  List<LearningLanguage> languages = const [];
  List<Course> courses = const [];
  List<LessonSummary> lessons = const [];
  Course? selectedCourse;
  Lesson? selectedLesson;
  String? selectedOptionId;
  AttemptFeedback? feedback;
  CourseProgress? courseProgress;
  PendingAttempt? _pendingAttempt;
  String? _requestedSourceLanguage;
  String? _requestedTargetLanguage;

  Future<void> loadCatalog() => _run(() async {
    languages = await _repository.languages();
    final context = learningContext();
    if (!context.complete) {
      step = LearningStep.catalog;
      return;
    }
    await _loadCourses(
      context.sourceLanguage!,
      context.targetLanguage!,
      activeCourseId: context.activeCourseId,
    );
  });

  Future<void> chooseLanguage(LearningLanguage language) async {
    final sourceLanguage = learningContext().sourceLanguage;
    if (sourceLanguage == null) {
      selectionError = 'learning_context_required';
      notifyListeners();
      return;
    }
    await loadCoursesFor(sourceLanguage, language.languageTag);
  }

  Future<void> loadCoursesFor(String sourceLanguage, String targetLanguage) =>
      _run(() => _loadCourses(sourceLanguage, targetLanguage));

  Future<void> _loadCourses(
    String sourceLanguage,
    String targetLanguage, {
    String? activeCourseId,
  }) async {
    _requestedSourceLanguage = sourceLanguage;
    _requestedTargetLanguage = targetLanguage;
    step = LearningStep.courses;
    courses = await _repository.courses(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    final active = courses.where((item) => item.id == activeCourseId);
    if (active.isNotEmpty) {
      selectedCourse = active.first;
      step = LearningStep.lessons;
      lessons = await _repository.lessons(active.first.id);
    }
  }

  Future<void> chooseCourse(Course course) => _run(() async {
    await onCourseSelected(course);
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
    _pendingAttempt = null;
    step = LearningStep.lesson;
  });

  void selectOption(String optionId) {
    if (selectedOptionId != optionId) {
      _pendingAttempt = null;
    }
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
      _pendingAttempt ??= _repository.createAttempt(
        lesson: lesson,
        exercise: lesson.exercises.first,
        response: OptionExerciseResponse(optionId),
      );
      feedback = await _repository.submitAttempt(_pendingAttempt!);
      _pendingAttempt = null;
      step = LearningStep.feedback;
    });
  }

  Future<void> showProgress() => _run(() async {
    final course = selectedCourse;
    if (course == null) return;
    courseProgress = await _repository.progress(course.id);
    step = LearningStep.progress;
  });

  void continueAfterQueued() {
    _pendingAttempt = null;
    selectedOptionId = null;
    step = LearningStep.lessons;
    notifyListeners();
  }

  Future<void> retry() async {
    switch (step) {
      case LearningStep.catalog:
        await loadCatalog();
      case LearningStep.courses:
        final sourceLanguage = _requestedSourceLanguage;
        final targetLanguage = _requestedTargetLanguage;
        if (sourceLanguage != null && targetLanguage != null) {
          await loadCoursesFor(sourceLanguage, targetLanguage);
        }
      case LearningStep.lessons:
        final course = selectedCourse;
        if (course != null) await chooseCourse(course);
      case LearningStep.lesson:
      case LearningStep.queued:
        if (_pendingAttempt != null) {
          await submitAnswer();
          return;
        }
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
    } on AttemptQueuedForSync {
      error = null;
      step = LearningStep.queued;
    } on Object catch (exception) {
      error = mapUserFacingFailure(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class LearningContextSnapshot {
  const LearningContextSnapshot({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.activeCourseId,
  });

  const LearningContextSnapshot.empty()
    : sourceLanguage = null,
      targetLanguage = null,
      activeCourseId = null;

  final String? sourceLanguage;
  final String? targetLanguage;
  final String? activeCourseId;

  bool get complete =>
      sourceLanguage != null &&
      targetLanguage != null &&
      activeCourseId != null;
}

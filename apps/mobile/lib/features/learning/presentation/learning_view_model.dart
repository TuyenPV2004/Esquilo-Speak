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
  ExerciseResponse? selectedResponse;
  int currentExerciseIndex = 0;
  bool hintVisible = false;
  int retryIndex = 0;
  bool reviewingMistakes = false;
  final List<int> mistakeExerciseIndexes = [];
  AttemptFeedback? feedback;
  CourseProgress? courseProgress;
  final Map<String, UnitDownloadStatus> unitDownloadStatuses = {};
  String? downloadingUnitId;
  PendingAttempt? _pendingAttempt;
  String? _requestedSourceLanguage;
  String? _requestedTargetLanguage;
  DateTime _exerciseStartedAt = DateTime.now();

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
      courseProgress = await _repository.progress(active.first.id);
      await _loadUnitDownloadStatuses(active.first.id);
    }
  }

  Future<void> chooseCourse(Course course) => _run(() async {
    await onCourseSelected(course);
    selectedCourse = course;
    step = LearningStep.lessons;
    lessons = await _repository.lessons(course.id);
    courseProgress = await _repository.progress(course.id);
    await _loadUnitDownloadStatuses(course.id);
  });

  Future<void> downloadUnit(String unitId) async {
    final course = selectedCourse;
    final store = _repository is UnitDownloadStore
        ? _repository as UnitDownloadStore
        : null;
    if (course == null || store == null) return;
    final unitLessons = lessons
        .where((lesson) => lesson.unitId == unitId)
        .toList(growable: false);
    downloadingUnitId = unitId;
    error = null;
    notifyListeners();
    try {
      unitDownloadStatuses[unitId] = await store.downloadUnit(
        courseId: course.id,
        unitId: unitId,
        lessons: unitLessons,
      );
    } on Object catch (exception) {
      error = mapUserFacingFailure(exception);
    } finally {
      downloadingUnitId = null;
      notifyListeners();
    }
  }

  Future<void> _loadUnitDownloadStatuses(String courseId) async {
    unitDownloadStatuses.clear();
    if (_repository is! UnitDownloadStore) return;
    final store = _repository as UnitDownloadStore;
    final unitIds = lessons.map((lesson) => lesson.unitId).whereType<String>();
    for (final unitId in unitIds.toSet()) {
      final unitLessons = lessons
          .where((lesson) => lesson.unitId == unitId)
          .toList(growable: false);
      unitDownloadStatuses[unitId] = await store.unitDownloadStatus(
        courseId: courseId,
        unitId: unitId,
        lessons: unitLessons,
      );
    }
  }

  Future<void> chooseLesson(LessonSummary summary) => _run(() async {
    selectedLesson = await _repository.lesson(
      summary.id,
      version: summary.version,
    );
    selectedOptionId = null;
    selectedResponse = null;
    currentExerciseIndex = 0;
    hintVisible = false;
    retryIndex = 0;
    reviewingMistakes = false;
    mistakeExerciseIndexes.clear();
    _exerciseStartedAt = DateTime.now();
    final store = _repository is LessonResumeStore
        ? _repository as LessonResumeStore
        : null;
    final resume = await store?.loadLessonResume(
      selectedLesson!.id,
      selectedLesson!.version,
    );
    if (resume != null &&
        resume.exerciseIndex >= 0 &&
        resume.exerciseIndex < selectedLesson!.exercises.length) {
      currentExerciseIndex = resume.exerciseIndex;
      mistakeExerciseIndexes.addAll(
        resume.mistakeExerciseIndexes.where(
          (index) => index >= 0 && index < selectedLesson!.exercises.length,
        ),
      );
      reviewingMistakes = resume.reviewingMistakes;
    }
    selectionError = null;
    _pendingAttempt = null;
    step = LearningStep.lesson;
  });

  void selectOption(String optionId) {
    setResponse(OptionExerciseResponse(optionId));
  }

  void setResponse(ExerciseResponse response) {
    final serialized = response.toJson().toString();
    if (selectedResponse?.toJson().toString() != serialized) {
      _pendingAttempt = null;
    }
    selectedResponse = response;
    selectedOptionId = response is OptionExerciseResponse
        ? response.optionId
        : null;
    selectionError = null;
    notifyListeners();
  }

  void showHint() {
    hintVisible = true;
    notifyListeners();
  }

  Future<void> submitAnswer() async {
    final lesson = selectedLesson;
    final response = _responseForSubmission();
    if (lesson == null || response == null) {
      selectionError = 'select_answer';
      notifyListeners();
      return;
    }
    await _run(() async {
      _pendingAttempt ??= _repository
          .createAttempt(
            lesson: lesson,
            exercise: lesson.exercises[currentExerciseIndex],
            response: response,
          )
          .withEvidence(
            AttemptEvidence(
              responseTimeMs: DateTime.now()
                  .difference(_exerciseStartedAt)
                  .inMilliseconds,
              hintUsed: hintVisible,
              hintLevel: hintVisible ? 1 : 0,
              retryIndex: retryIndex,
            ),
          );
      feedback = await _repository.submitAttempt(_pendingAttempt!);
      if (!feedback!.correct &&
          !mistakeExerciseIndexes.contains(currentExerciseIndex)) {
        mistakeExerciseIndexes.add(currentExerciseIndex);
      }
      await _persistResume();
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

  void continueFromProgress() {
    selectedLesson = null;
    feedback = null;
    step = LearningStep.lessons;
    notifyListeners();
  }

  ExerciseResponse? _responseForSubmission() {
    final lesson = selectedLesson;
    if (lesson == null) return null;
    final exercise = lesson.exercises[currentExerciseIndex];
    final response = selectedResponse;
    if (response is TextExerciseResponse && response.text.trim().isEmpty) {
      return null;
    }
    if (exercise.type == 'ordering' && response == null) {
      return SequenceExerciseResponse(
        exercise.items.map((item) => item.id).toList(),
      );
    }
    if (exercise.type == 'matching' &&
        response is PairExerciseResponse &&
        response.pairs.length != exercise.leftItems.length) {
      return null;
    }
    return response;
  }

  Future<void> continueAfterFeedback() async {
    final lesson = selectedLesson;
    final result = feedback;
    if (lesson == null || result == null) return;
    if (reviewingMistakes) {
      if (result.correct) {
        mistakeExerciseIndexes.remove(currentExerciseIndex);
      }
      if (mistakeExerciseIndexes.isNotEmpty) {
        final position = mistakeExerciseIndexes.indexOf(currentExerciseIndex);
        currentExerciseIndex =
            mistakeExerciseIndexes[position < 0 ||
                    position == mistakeExerciseIndexes.length - 1
                ? 0
                : position + 1];
        _prepareExercise(retry: !result.correct);
        await _persistResume();
        return;
      }
      await _finishLesson();
      return;
    }
    if (currentExerciseIndex < lesson.exercises.length - 1) {
      currentExerciseIndex += 1;
      _prepareExercise();
      await _persistResume();
      return;
    }
    if (mistakeExerciseIndexes.isNotEmpty) {
      reviewingMistakes = true;
      currentExerciseIndex = mistakeExerciseIndexes.first;
      _prepareExercise(retry: true);
      await _persistResume();
      return;
    }
    await _finishLesson();
  }

  Future<void> _persistResume() async {
    final lesson = selectedLesson;
    if (lesson == null || _repository is! LessonResumeStore) return;
    await (_repository as LessonResumeStore).saveLessonResume(
      LessonResume(
        lessonId: lesson.id,
        lessonVersion: lesson.version,
        exerciseIndex: currentExerciseIndex,
        mistakeExerciseIndexes: [...mistakeExerciseIndexes],
        reviewingMistakes: reviewingMistakes,
      ),
    );
  }

  Future<void> _finishLesson() async {
    final lesson = selectedLesson;
    if (lesson != null && _repository is LessonResumeStore) {
      await (_repository as LessonResumeStore).clearLessonResume(
        lesson.id,
        lesson.version,
      );
    }
    await showProgress();
  }

  void _prepareExercise({bool retry = false}) {
    selectedOptionId = null;
    selectedResponse = null;
    selectionError = null;
    hintVisible = false;
    retryIndex = retry ? retryIndex + 1 : 0;
    feedback = null;
    _pendingAttempt = null;
    _exerciseStartedAt = DateTime.now();
    step = LearningStep.lesson;
    notifyListeners();
  }

  void continueAfterQueued() {
    _pendingAttempt = null;
    selectedOptionId = null;
    selectedResponse = null;
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

import 'package:flutter/foundation.dart';

import '../../../core/network/user_facing_failure.dart';
import '../data/learning_models.dart';
import '../data/offline_learning_repository.dart';
import '../data/learning_repository.dart';
import '../../practice/data/practice_models.dart';

enum LearningStep {
  catalog,
  courses,
  lessons,
  lesson,
  queued,
  feedback,
  progress,
}

enum LearningSessionKind { lesson, dailyQuickPractice, practice }

class LearningCompletion {
  const LearningCompletion({
    required this.kind,
    required this.courseId,
    required this.lessonId,
    required this.exerciseCount,
    required this.mistakeCount,
    required this.conceptIds,
  });

  final LearningSessionKind kind;
  final String courseId;
  final String lessonId;
  final int exerciseCount;
  final int mistakeCount;
  final List<String> conceptIds;
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
  Future<void> Function(LearningCompletion completion)? onLearningCompleted;

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
  LearningSessionKind sessionKind = LearningSessionKind.lesson;
  int sessionMistakeCount = 0;
  int sessionCorrectCount = 0;
  PracticeMode? activePracticeMode;
  String? practiceExplanationCode;
  bool practiceUsedFallback = false;
  bool flashcardRevealed = false;
  final Set<String> _sessionMistakeExerciseIds = {};
  final Set<String> _sessionCorrectExerciseIds = {};
  final Map<String, Lesson> _practiceSources = {};
  final Map<String, String> _practiceMediaIds = {};
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
    sessionKind = LearningSessionKind.lesson;
    activePracticeMode = null;
    practiceExplanationCode = null;
    practiceUsedFallback = false;
    _practiceSources.clear();
    _practiceMediaIds.clear();
    _resetSessionState();
    await _restoreResume();
    step = LearningStep.lesson;
  });

  Future<void> startQuickPractice({
    required Iterable<String> conceptIds,
    required int exerciseCount,
  }) => _run(() async {
    final requestedConcepts = conceptIds.toSet();
    final candidates = [...lessons]
      ..sort((left, right) {
        final leftDownloaded =
            left.unitId != null &&
            (unitDownloadStatuses[left.unitId]?.downloaded ?? false);
        final rightDownloaded =
            right.unitId != null &&
            (unitDownloadStatuses[right.unitId]?.downloaded ?? false);
        if (leftDownloaded != rightDownloaded) return leftDownloaded ? -1 : 1;
        return (left.position ?? 0).compareTo(right.position ?? 0);
      });
    Lesson? source;
    List<Exercise> selectedExercises = const [];
    for (final summary in candidates) {
      Lesson candidate;
      try {
        candidate = await _repository.lesson(
          summary.id,
          version: summary.version,
        );
      } on Object {
        continue;
      }
      final matching = candidate.exercises
          .where(
            (exercise) =>
                requestedConcepts.isEmpty ||
                exercise.conceptIds.any(requestedConcepts.contains),
          )
          .toList();
      if (matching.isEmpty && requestedConcepts.isNotEmpty) continue;
      final combined = <Exercise>[...matching];
      for (final exercise in candidate.exercises) {
        if (combined.length >= exerciseCount) break;
        if (!combined.any((item) => item.id == exercise.id)) {
          combined.add(exercise);
        }
      }
      if (combined.isEmpty) continue;
      source = candidate;
      selectedExercises = combined.take(exerciseCount).toList(growable: false);
      break;
    }
    if (source == null || selectedExercises.isEmpty) {
      throw StateError(
        'No cached or reachable lesson supports quick practice.',
      );
    }
    selectedLesson = Lesson(
      id: source.id,
      courseId: source.courseId,
      version: source.version,
      locale: source.locale,
      title: source.title,
      objectives: source.objectives,
      exercises: selectedExercises,
    );
    sessionKind = LearningSessionKind.dailyQuickPractice;
    activePracticeMode = null;
    _practiceSources.clear();
    _practiceMediaIds.clear();
    _resetSessionState();
    step = LearningStep.lesson;
  });

  Future<void> startPractice({
    required PracticeConfiguration configuration,
    Map<String, double> masteryByConcept = const {},
    Set<String> dueConceptIds = const {},
  }) => _run(() async {
    final course = selectedCourse;
    if (course == null) throw StateError('Select a course before practice.');
    final recentMistakes = _repository is PracticeHistoryStore
        ? (await (_repository as PracticeHistoryStore).recentMistakeExerciseIds(
            course.id,
          )).toSet()
        : const <String>{};
    final candidates = <PracticeCandidate>[];
    for (final summary in lessons) {
      try {
        final lesson = await _repository.lesson(
          summary.id,
          version: summary.version,
        );
        for (final exercise in lesson.exercises) {
          candidates.add(
            PracticeCandidate(
              lesson: lesson,
              exercise: exercise,
              unitId: summary.unitId,
            ),
          );
        }
      } on Object {
        continue;
      }
    }
    final selection = const PracticeSelector().select(
      configuration: configuration,
      candidates: candidates,
      masteryByConcept: masteryByConcept,
      dueConceptIds: dueConceptIds,
      recentMistakeExerciseIds: recentMistakes,
    );
    if (selection.items.isEmpty) {
      throw StateError(
        'No cached or reachable content supports this practice.',
      );
    }
    final first = selection.items.first.lesson;
    _practiceSources
      ..clear()
      ..addEntries(
        selection.items.map((item) => MapEntry(item.exercise.id, item.lesson)),
      );
    _practiceMediaIds.clear();
    for (final item in selection.items) {
      final directMedia = item.exercise.mediaId;
      String? relatedMedia;
      for (final candidate in candidates) {
        if (candidate.exercise.mediaId != null &&
            candidate.exercise.conceptIds.any(
              item.exercise.conceptIds.contains,
            )) {
          relatedMedia = candidate.exercise.mediaId;
          break;
        }
      }
      final mediaId = directMedia ?? relatedMedia;
      if (mediaId != null) _practiceMediaIds[item.exercise.id] = mediaId;
    }
    selectedLesson = Lesson(
      id: 'practice-${configuration.mode.apiValue}',
      courseId: first.courseId,
      version: first.version,
      locale: first.locale,
      title: first.title,
      objectives: first.objectives,
      exercises: selection.items
          .map((item) => item.exercise)
          .toList(growable: false),
    );
    sessionKind = LearningSessionKind.practice;
    activePracticeMode = configuration.mode;
    practiceExplanationCode = selection.explanationCode;
    practiceUsedFallback = selection.usedFallback;
    _resetSessionState();
    step = LearningStep.lesson;
  });

  void shufflePractice() {
    final lesson = selectedLesson;
    if (sessionKind != LearningSessionKind.practice ||
        activePracticeMode != PracticeMode.flashcards ||
        lesson == null ||
        lesson.exercises.length < 2) {
      return;
    }
    final exercises = [...lesson.exercises]..shuffle();
    selectedLesson = Lesson(
      id: lesson.id,
      courseId: lesson.courseId,
      version: lesson.version,
      locale: lesson.locale,
      title: lesson.title,
      objectives: lesson.objectives,
      exercises: exercises,
    );
    _resetSessionState();
    notifyListeners();
  }

  void flipFlashcard() {
    flashcardRevealed = !flashcardRevealed;
    notifyListeners();
  }

  String? get currentExerciseMediaId {
    final lesson = selectedLesson;
    if (lesson == null || currentExerciseIndex >= lesson.exercises.length) {
      return null;
    }
    final exercise = lesson.exercises[currentExerciseIndex];
    return exercise.mediaId ?? _practiceMediaIds[exercise.id];
  }

  void _resetSessionState() {
    selectedOptionId = null;
    selectedResponse = null;
    currentExerciseIndex = 0;
    hintVisible = false;
    retryIndex = 0;
    reviewingMistakes = false;
    mistakeExerciseIndexes.clear();
    _sessionMistakeExerciseIds.clear();
    _sessionCorrectExerciseIds.clear();
    sessionMistakeCount = 0;
    sessionCorrectCount = 0;
    flashcardRevealed = false;
    _exerciseStartedAt = DateTime.now();
    selectionError = null;
    _pendingAttempt = null;
  }

  Future<void> _restoreResume() async {
    final lesson = selectedLesson;
    if (lesson == null || sessionKind != LearningSessionKind.lesson) return;
    final store = _repository is LessonResumeStore
        ? _repository as LessonResumeStore
        : null;
    final resume = await store?.loadLessonResume(lesson.id, lesson.version);
    if (resume != null &&
        resume.exerciseIndex >= 0 &&
        resume.exerciseIndex < lesson.exercises.length) {
      currentExerciseIndex = resume.exerciseIndex;
      mistakeExerciseIndexes.addAll(
        resume.mistakeExerciseIndexes.where(
          (index) => index >= 0 && index < lesson.exercises.length,
        ),
      );
      reviewingMistakes = resume.reviewingMistakes;
    }
  }

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
      final exercise = lesson.exercises[currentExerciseIndex];
      final sourceLesson = _practiceSources[exercise.id] ?? lesson;
      _pendingAttempt ??= _repository
          .createAttempt(
            lesson: sourceLesson,
            exercise: exercise,
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
              practiceMode: switch (sessionKind) {
                LearningSessionKind.dailyQuickPractice =>
                  'daily_quick_practice',
                LearningSessionKind.practice => activePracticeMode?.apiValue,
                LearningSessionKind.lesson => null,
              },
            ),
          );
      feedback = await _repository.submitAttempt(_pendingAttempt!);
      if (!feedback!.correct &&
          !mistakeExerciseIndexes.contains(currentExerciseIndex)) {
        mistakeExerciseIndexes.add(currentExerciseIndex);
      }
      if (!feedback!.correct &&
          _sessionMistakeExerciseIds.add(
            lesson.exercises[currentExerciseIndex].id,
          )) {
        sessionMistakeCount += 1;
      }
      if (feedback!.correct && _sessionCorrectExerciseIds.add(exercise.id)) {
        sessionCorrectCount += 1;
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
    if (sessionKind == LearningSessionKind.practice) {
      await _finishLesson();
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
    if (lesson == null ||
        sessionKind != LearningSessionKind.lesson ||
        _repository is! LessonResumeStore) {
      return;
    }
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
    if (lesson != null &&
        sessionKind == LearningSessionKind.lesson &&
        _repository is LessonResumeStore) {
      await (_repository as LessonResumeStore).clearLessonResume(
        lesson.id,
        lesson.version,
      );
    }
    await showProgress();
    if (lesson != null) {
      await onLearningCompleted?.call(
        LearningCompletion(
          kind: sessionKind,
          courseId: lesson.courseId,
          lessonId: lesson.id,
          exerciseCount: lesson.exercises.length,
          mistakeCount: sessionMistakeCount,
          conceptIds: lesson.exercises
              .expand((exercise) => exercise.conceptIds)
              .toSet()
              .toList(growable: false),
        ),
      );
    }
  }

  void _prepareExercise({bool retry = false}) {
    selectedOptionId = null;
    selectedResponse = null;
    selectionError = null;
    hintVisible = false;
    flashcardRevealed = false;
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

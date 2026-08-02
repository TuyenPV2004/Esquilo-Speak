import '../../../core/network/api_problem.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

class OfflineLearningRepository
    implements
        LearningRepository,
        LessonResumeStore,
        UnitDownloadStore,
        PracticeHistoryStore {
  OfflineLearningRepository(this._remote, this._sync, this._database);

  final LearningRepository _remote;
  final SyncCoordinator _sync;
  final AppDatabase _database;

  @override
  Future<List<LearningLanguage>> languages() => _cachedList(
    key: 'learning.languages',
    remote: _remote.languages,
    decode: LearningLanguage.fromJson,
    encode: (item) => item.toJson(),
  );

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) => _cachedList(
    key: 'learning.courses.$sourceLanguage.$targetLanguage',
    remote: () => _remote.courses(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    ),
    decode: Course.fromJson,
    encode: (item) => item.toJson(),
  );

  @override
  Future<List<LessonSummary>> lessons(String courseId) => _cachedList(
    key: 'learning.lessons.$courseId',
    remote: () => _remote.lessons(courseId),
    decode: LessonSummary.fromJson,
    encode: (item) => item.toJson(),
  );

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async {
    final key = 'learning.lesson.$lessonId.${version ?? 'current'}';
    try {
      final item = await _remote.lesson(lessonId, version: version);
      await _database.cacheJson(key, item.toJson());
      return item;
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson(key);
      if (cached == null) rethrow;
      return Lesson.fromJson(cached);
    }
  }

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required ExerciseResponse response,
  }) => _remote.createAttempt(
    lesson: lesson,
    exercise: exercise,
    response: response,
  );

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    await _sync.enqueueAttempt(
      clientMutationId: attempt.clientMutationId,
      idempotencyKey: attempt.idempotencyKey,
      payload: attempt.toJson(),
      occurredAt: attempt.occurredAt,
    );
    SyncRunResult result;
    try {
      result = await _sync.synchronize();
    } on Object catch (error) {
      if (_canUseCache(error)) throw const AttemptQueuedForSync();
      rethrow;
    }
    final attemptResult = result.results[attempt.clientMutationId];
    if (attemptResult == null) throw const AttemptQueuedForSync();
    final feedback = AttemptFeedback.fromJson(attemptResult);
    await _database.recordPracticeAttempt(
      clientAttemptId: attempt.clientAttemptId,
      courseId: attempt.courseId,
      lessonId: attempt.lessonId,
      lessonVersion: attempt.lessonVersion,
      exerciseId: attempt.exerciseId,
      correct: feedback.correct,
      practiceMode: attempt.evidence.practiceMode,
      occurredAt: attempt.occurredAt,
    );
    return feedback;
  }

  @override
  Future<List<String>> recentMistakeExerciseIds(String courseId) =>
      _database.recentMistakeExerciseIds(courseId);

  @override
  Future<CourseProgress> progress(String courseId) async {
    final key = 'learning.progress.$courseId';
    try {
      final item = await _remote.progress(courseId);
      await _database.cacheJson(key, item.toJson());
      return item;
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson(key);
      if (cached == null) rethrow;
      return CourseProgress.fromJson(cached);
    }
  }

  Future<List<T>> _cachedList<T>({
    required String key,
    required Future<List<T>> Function() remote,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  }) async {
    try {
      final items = await remote();
      await _database.cacheJson(key, {
        'items': items.map(encode).toList(growable: false),
      });
      return items;
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson(key);
      if (cached == null) rethrow;
      return (cached['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(decode)
          .toList(growable: false);
    }
  }

  bool _canUseCache(Object error) =>
      error is NetworkUnavailable || (error is ApiProblem && error.retryable);

  String _resumeKey(String lessonId, int version) =>
      'learning.resume.$lessonId.$version';

  @override
  Future<LessonResume?> loadLessonResume(String lessonId, int version) async {
    final value = await _database.cachedJson(_resumeKey(lessonId, version));
    return value == null ? null : LessonResume.fromJson(value);
  }

  @override
  Future<void> saveLessonResume(LessonResume resume) => _database.cacheJson(
    _resumeKey(resume.lessonId, resume.lessonVersion),
    resume.toJson(),
  );

  @override
  Future<void> clearLessonResume(String lessonId, int version) =>
      _database.deleteCachedJson(_resumeKey(lessonId, version));

  String _downloadKey(String courseId, String unitId) =>
      'learning.download.$courseId.$unitId';

  @override
  Future<UnitDownloadStatus> unitDownloadStatus({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  }) async {
    final manifest = await _database.cachedJson(_downloadKey(courseId, unitId));
    final versions = manifest == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(
            manifest['lessonVersions'] as Map? ?? const {},
          );
    var downloadedCount = 0;
    for (final summary in lessons) {
      if (versions[summary.id] != summary.version) continue;
      final cached = await _database.cachedJson(
        'learning.lesson.${summary.id}.${summary.version}',
      );
      if (cached != null) downloadedCount += 1;
    }
    return UnitDownloadStatus(
      courseId: courseId,
      unitId: unitId,
      downloadedLessonCount: downloadedCount,
      totalLessonCount: lessons.length,
      updatedAt: manifest?['updatedAt'] == null
          ? null
          : DateTime.tryParse(manifest!['updatedAt'] as String),
    );
  }

  @override
  Future<UnitDownloadStatus> downloadUnit({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  }) async {
    if (lessons.isEmpty || lessons.any((item) => item.unitId != unitId)) {
      throw ArgumentError.value(unitId, 'unitId', 'Unit lessons are invalid.');
    }
    for (final summary in lessons) {
      final item = await _remote.lesson(summary.id, version: summary.version);
      await _database.cacheJson(
        'learning.lesson.${summary.id}.${summary.version}',
        item.toJson(),
      );
      await _database.cacheJson(
        'learning.lesson.${summary.id}.current',
        item.toJson(),
      );
    }
    final updatedAt = DateTime.now().toUtc();
    await _database.cacheJson(_downloadKey(courseId, unitId), {
      'courseId': courseId,
      'unitId': unitId,
      'lessonVersions': {
        for (final summary in lessons) summary.id: summary.version,
      },
      'updatedAt': updatedAt.toIso8601String(),
    });
    return UnitDownloadStatus(
      courseId: courseId,
      unitId: unitId,
      downloadedLessonCount: lessons.length,
      totalLessonCount: lessons.length,
      updatedAt: updatedAt,
    );
  }
}

class AttemptQueuedForSync implements Exception {
  const AttemptQueuedForSync();
}

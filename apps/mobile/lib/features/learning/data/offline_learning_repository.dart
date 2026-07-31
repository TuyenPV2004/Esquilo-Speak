import '../../../core/network/api_problem.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

class OfflineLearningRepository implements LearningRepository {
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
    return AttemptFeedback.fromJson(attemptResult);
  }

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
}

class AttemptQueuedForSync implements Exception {
  const AttemptQueuedForSync();
}

import '../../../core/sync/sync_coordinator.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

class OfflineLearningRepository implements LearningRepository {
  OfflineLearningRepository(this._remote, this._sync);

  final LearningRepository _remote;
  final SyncCoordinator _sync;

  @override
  Future<List<LearningLanguage>> languages() => _remote.languages();

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) => _remote.courses(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
  );

  @override
  Future<List<LessonSummary>> lessons(String courseId) =>
      _remote.lessons(courseId);

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) =>
      _remote.lesson(lessonId, version: version);

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required String selectedOptionId,
  }) => _remote.createAttempt(
    lesson: lesson,
    exercise: exercise,
    selectedOptionId: selectedOptionId,
  );

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    await _sync.enqueueAttempt(
      clientMutationId: attempt.clientMutationId,
      idempotencyKey: attempt.idempotencyKey,
      payload: attempt.toJson(),
      occurredAt: attempt.occurredAt,
    );
    final result = await _sync.synchronize();
    final attemptResult = result.results[attempt.clientMutationId];
    if (attemptResult == null) throw const AttemptQueuedForSync();
    return AttemptFeedback.fromJson(attemptResult);
  }

  @override
  Future<CourseProgress> progress(String courseId) =>
      _remote.progress(courseId);
}

class AttemptQueuedForSync implements Exception {
  const AttemptQueuedForSync();

  @override
  String toString() =>
      'Your answer is saved on this device and will sync when possible.';
}

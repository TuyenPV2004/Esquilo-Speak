import 'package:uuid/uuid.dart';

import 'learning_api_service.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

class RemoteLearningRepository implements LearningRepository {
  RemoteLearningRepository(this._api);

  final LearningApiService _api;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<LearningLanguage>> languages() async {
    final payload = await _api.get('/api/mobile/v1/languages');
    return _items(payload).map(LearningLanguage.fromJson).toList();
  }

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final payload = await _api.get(
      '/api/mobile/v1/courses',
      query: {
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
      },
    );
    return _items(payload).map(Course.fromJson).toList();
  }

  @override
  Future<List<LessonSummary>> lessons(String courseId) async {
    final payload = await _api.get('/api/mobile/v1/courses/$courseId/lessons');
    return _items(payload).map(LessonSummary.fromJson).toList();
  }

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async {
    final payload = await _api.get(
      '/api/mobile/v1/lessons/$lessonId',
      query: version == null ? null : {'version': '$version'},
    );
    return Lesson.fromJson(payload);
  }

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required String selectedOptionId,
  }) {
    return PendingAttempt(
      clientAttemptId: _uuid.v4(),
      idempotencyKey: _uuid.v4(),
      courseId: lesson.courseId,
      lessonId: lesson.id,
      lessonVersion: lesson.version,
      exerciseId: exercise.id,
      selectedOptionId: selectedOptionId,
      occurredAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    final payload = await _api.post(
      '/api/mobile/v1/attempts',
      authenticated: true,
      idempotencyKey: attempt.idempotencyKey,
      body: attempt.toJson(),
    );
    return AttemptFeedback.fromJson(payload);
  }

  @override
  Future<CourseProgress> progress(String courseId) async {
    final payload = await _api.get(
      '/api/mobile/v1/progress/courses/$courseId',
      authenticated: true,
    );
    return CourseProgress.fromJson(payload);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> payload) =>
      (payload['items'] as List<dynamic>).cast<Map<String, dynamic>>();
}

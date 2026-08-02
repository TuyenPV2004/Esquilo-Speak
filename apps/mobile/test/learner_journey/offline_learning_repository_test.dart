import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/network/api_problem.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/core/sync/sync_coordinator.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_repository.dart';
import 'package:esquilospeak_mobile/features/learning/data/offline_learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('serves cached content and queues an attempt while offline', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);
    final remote = _ToggleRepository();
    final api = ApiClient(
      MockClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
      Uri.parse('https://api.example.test'),
      const _TokenProvider(),
      maxAttempts: 1,
    );
    final repository = OfflineLearningRepository(
      remote,
      SyncCoordinator(database, api),
      database,
    );

    expect(await repository.languages(), hasLength(1));
    remote.offline = true;
    expect((await repository.languages()).single.languageTag, 'en');

    final attempt = repository.createAttempt(
      lesson: _lesson,
      exercise: _lesson.exercises.single,
      response: const OptionExerciseResponse('option-hello'),
    );
    await expectLater(
      repository.submitAttempt(attempt),
      throwsA(isA<AttemptQueuedForSync>()),
    );
    expect(await database.pendingMutationCount(), 1);

    const resume = LessonResume(
      lessonId: 'lesson-basic-greetings',
      lessonVersion: 1,
      exerciseIndex: 0,
      mistakeExerciseIndexes: [0],
      reviewingMistakes: true,
    );
    await repository.saveLessonResume(resume);
    final restored = await repository.loadLessonResume(
      resume.lessonId,
      resume.lessonVersion,
    );
    expect(restored?.mistakeExerciseIndexes, [0]);
    expect(restored?.reviewingMistakes, true);
    await repository.clearLessonResume(resume.lessonId, resume.lessonVersion);
    expect(
      await repository.loadLessonResume(resume.lessonId, resume.lessonVersion),
      isNull,
    );
  });

  test(
    'downloads a complete unit and serves its exact lesson offline',
    () async {
      final database = AppDatabase(factory: databaseFactoryFfi);
      await database.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final remote = _ToggleRepository();
      final api = ApiClient(
        MockClient((request) async => http.Response('{}', 200)),
        Uri.parse('https://api.example.test'),
        const _TokenProvider(),
        maxAttempts: 1,
      );
      final repository = OfflineLearningRepository(
        remote,
        SyncCoordinator(database, api),
        database,
      );

      const summaries = [
        LessonSummary(
          id: 'lesson-basic-greetings',
          version: 1,
          title: {'en': 'Greetings'},
          estimatedMinutes: 5,
          unitId: 'unit-first-contact',
          unitTitle: {'en': 'First contact'},
          position: 1,
        ),
      ];
      final first = await repository.downloadUnit(
        courseId: 'course-en-for-vi',
        unitId: 'unit-first-contact',
        lessons: summaries,
      );
      final second = await repository.downloadUnit(
        courseId: 'course-en-for-vi',
        unitId: 'unit-first-contact',
        lessons: summaries,
      );
      expect(first.downloaded, true);
      expect(second.downloadedLessonCount, 1);
      expect(remote.lessonRequests, 2);

      remote.offline = true;
      final restored = await repository.lesson(
        'lesson-basic-greetings',
        version: 1,
      );
      expect(restored.id, 'lesson-basic-greetings');
      expect(
        (await repository.unitDownloadStatus(
          courseId: 'course-en-for-vi',
          unitId: 'unit-first-contact',
          lessons: summaries,
        )).downloaded,
        true,
      );
    },
  );
}

class _ToggleRepository implements LearningRepository {
  bool offline = false;
  int lessonRequests = 0;

  @override
  Future<List<LearningLanguage>> languages() async {
    if (offline) throw const NetworkUnavailable();
    return const [
      LearningLanguage(
        id: 'language-en',
        languageTag: 'en',
        name: {'en': 'English', 'vi': 'Tiếng Anh'},
      ),
    ];
  }

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required ExerciseResponse response,
  }) => PendingAttempt(
    clientAttemptId: '11111111-1111-4111-8111-111111111111',
    clientMutationId: '22222222-2222-4222-8222-222222222222',
    idempotencyKey: '33333333-3333-4333-8333-333333333333',
    courseId: lesson.courseId,
    lessonId: lesson.id,
    lessonVersion: lesson.version,
    exerciseId: exercise.id,
    response: response,
    occurredAt: DateTime.utc(2026, 7, 30),
  );

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) async => const [];

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async {
    lessonRequests += 1;
    if (offline) throw const NetworkUnavailable();
    return _lesson;
  }

  @override
  Future<List<LessonSummary>> lessons(String courseId) async => const [];

  @override
  Future<CourseProgress> progress(String courseId) async =>
      const CourseProgress(
        courseId: 'course-en-for-vi',
        completedExerciseCount: 0,
        totalExerciseCount: 1,
      );

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    throw UnimplementedError();
  }
}

const _lesson = Lesson(
  id: 'lesson-basic-greetings',
  courseId: 'course-en-for-vi',
  version: 1,
  title: {'vi': 'Lời chào', 'en': 'Greetings'},
  objectives: [
    {'vi': 'Nhận biết lời chào', 'en': 'Recognize greetings'},
  ],
  exercises: [
    Exercise(
      id: 'exercise-hello',
      type: 'multiple_choice',
      prompt: {'vi': 'Chọn lời chào', 'en': 'Choose the greeting'},
      options: [
        ExerciseOption(
          id: 'option-hello',
          text: {'vi': 'Hello', 'en': 'Hello'},
        ),
      ],
    ),
  ],
);

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

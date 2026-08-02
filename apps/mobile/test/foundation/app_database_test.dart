import 'dart:io';

import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('persists a mutation and applies a canonical sync result', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);
    final mutation = LocalMutation(
      clientMutationId: '11111111-1111-4111-8111-111111111111',
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
      type: 'attempt.submit',
      payload: {
        'response': {'kind': 'option', 'optionId': 'option-hello'},
      },
      occurredAt: DateTime.utc(2026, 7, 30),
    );

    await database.enqueueMutation(mutation);
    await database.enqueueMutation(mutation);

    expect(await database.pendingMutations(), hasLength(1));

    await database.applySyncResult(
      appliedMutationIds: [mutation.clientMutationId],
      changes: [
        CanonicalChange(
          entityType: 'attempt',
          entityId: 'attempt-1',
          operation: 'upsert',
          payload: {'correct': true},
          occurredAt: DateTime.utc(2026, 7, 30, 0, 1),
        ),
      ],
      nextCursor: 'v1.cursor',
    );

    expect(await database.pendingMutations(), isEmpty);
    expect(await database.syncCursor(), 'v1.cursor');

    await database.cacheJson('lesson.lesson-basic-greetings.1', {
      'id': 'lesson-basic-greetings',
      'version': 1,
    });
    expect(await database.cachedJson('lesson.lesson-basic-greetings.1'), {
      'id': 'lesson-basic-greetings',
      'version': 1,
    });
  });

  test('upgrades a phase 10 database before writing content cache', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'esquilospeak-db-upgrade-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final path = '${temporaryDirectory.path}/phase-10.db';
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE pending_mutation (
              client_mutation_id TEXT PRIMARY KEY,
              idempotency_key TEXT NOT NULL,
              mutation_type TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              next_attempt_at TEXT,
              last_error_code TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE canonical_change (
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              PRIMARY KEY (entity_type, entity_id)
            )
          ''');
          await database.execute('''
            CREATE TABLE app_state (
              state_key TEXT PRIMARY KEY,
              state_value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await legacyDatabase.close();

    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: path);
    addTearDown(database.close);
    await database.cacheJson('course.english-for-vietnamese', {
      'id': 'english-for-vietnamese',
    });

    expect(await database.cachedJson('course.english-for-vietnamese'), {
      'id': 'english-for-vietnamese',
    });
    expect(await database.recentMistakeExerciseIds('course-1'), isEmpty);
  });

  test('recent mistakes use the latest saved result per exercise', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);

    Future<void> record(String id, String exercise, bool correct, int minute) =>
        database.recordPracticeAttempt(
          clientAttemptId: id,
          courseId: 'course-1',
          lessonId: 'lesson-1',
          lessonVersion: 1,
          exerciseId: exercise,
          correct: correct,
          practiceMode: 'mistakes',
          occurredAt: DateTime.utc(2026, 8, 2, 12, minute),
        );

    await record('attempt-a', 'exercise-fixed', false, 1);
    await record('attempt-b', 'exercise-still-wrong', false, 2);
    await record('attempt-c', 'exercise-fixed', true, 3);

    expect(await database.recentMistakeExerciseIds('course-1'), [
      'exercise-still-wrong',
    ]);
  });
}

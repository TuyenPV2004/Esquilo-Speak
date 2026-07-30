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
      payload: {'selectedOptionId': 'option-hello'},
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
  });
}

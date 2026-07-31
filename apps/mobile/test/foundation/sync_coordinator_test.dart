import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/core/sync/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('pushes the durable outbox then advances the pull cursor', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/sync/push')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final mutation =
            (body['mutations'] as List<dynamic>).single as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'clientBatchId': body['clientBatchId'],
            'rebased': false,
            'nextCursor': 'v1.1',
            'results': [
              {
                'clientMutationId': mutation['clientMutationId'],
                'status': 'applied',
                'result': {'correct': true},
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'nextCursor': 'v1.1',
          'hasMore': false,
          'changes': <Object?>[],
        }),
        200,
      );
    });
    final coordinator = SyncCoordinator(
      database,
      ApiClient(
        client,
        Uri.parse('https://api.example.test'),
        const _TokenProvider(),
      ),
    );
    const mutationId = '11111111-1111-4111-8111-111111111111';
    await coordinator.enqueueAttempt(
      clientMutationId: mutationId,
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
      payload: const {
        'response': {'kind': 'option', 'optionId': 'option-hello'},
      },
      occurredAt: DateTime.utc(2026, 7, 30),
    );

    final result = await coordinator.synchronize();

    expect(result.results[mutationId]?['correct'], isTrue);
    expect(await database.pendingMutations(), isEmpty);
    expect(await database.syncCursor(), 'v1.1');
    expect(requests.map((request) => request.url.path), [
      '/api/mobile/v1/sync/push',
      '/api/mobile/v1/sync/pull',
    ]);
  });
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async =>
      'test-token';
}

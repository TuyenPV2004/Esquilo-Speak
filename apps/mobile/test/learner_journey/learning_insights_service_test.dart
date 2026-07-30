import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/features/review/data/learning_insights_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('falls back to cached mastery and review data', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);
    var offline = false;
    final client = MockClient((request) async {
      if (offline) throw http.ClientException('offline', request.url);
      if (request.url.path.endsWith('/mastery')) {
        return _json({
          'modelVersion': 1,
          'items': [
            {
              'conceptId': 'greeting.hello',
              'modelVersion': 1,
              'score': 1.0,
              'correctEvidenceCount': 1,
              'evidenceCount': 1,
              'lastEvidenceAt': '2026-07-30T00:00:00Z',
              'explanation': {},
            },
          ],
        });
      }
      return _json({
        'generatedAt': '2026-07-30T00:00:00Z',
        'items': [
          {
            'conceptId': 'greeting.hello',
            'modelVersion': 1,
            'dueAt': '2026-07-30T00:00:00Z',
            'intervalDays': 1,
            'easeFactor': 2.5,
            'repetitions': 1,
            'lastResult': 'correct',
          },
        ],
      });
    });
    final service = LearningInsightsService(
      ApiClient(
        client,
        Uri.parse('https://api.example.test'),
        const _TokenProvider(),
        maxAttempts: 1,
      ),
      database,
    );

    final online = await service.load();
    expect(online.fromCache, isFalse);
    expect(online.mastery, hasLength(1));

    offline = true;
    final cached = await service.load();
    expect(cached.fromCache, isTrue);
    expect(cached.reviews.single.conceptId, 'greeting.hello');
  });
}

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

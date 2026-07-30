import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/features/review/data/learning_insights_models.dart';
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
              'explanation': {'method': 'weighted-correct-ratio'},
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
    expect(online.mastery.single.lastEvidenceAt, DateTime.utc(2026, 7, 30));
    expect(online.mastery.single.calculationMethod, 'weighted-correct-ratio');
    expect(online.recommendation.kind, LearningRecommendationKind.reviewDue);
    expect(online.recommendation.algorithmVersion, 1);

    offline = true;
    final cached = await service.load();
    expect(cached.fromCache, isTrue);
    expect(cached.reviews.single.conceptId, 'greeting.hello');
    expect(cached.recommendation.kind, LearningRecommendationKind.reviewDue);
  });

  test('recommends the weakest concept when nothing is due', () async {
    final insights = await _loadInsights(
      mastery: [
        _mastery('greeting.hello', 0.75),
        _mastery('greeting.goodbye', 0.25),
      ],
      reviews: const [],
    );

    expect(
      insights.recommendation.kind,
      LearningRecommendationKind.strengthenWeakConcept,
    );
    expect(insights.recommendation.conceptId, 'greeting.goodbye');
    expect(insights.recommendation.masteryScore, 0.25);
  });

  test('continues learning when current mastery is complete', () async {
    final insights = await _loadInsights(
      mastery: [_mastery('greeting.hello', 1)],
      reviews: const [],
    );

    expect(
      insights.recommendation.kind,
      LearningRecommendationKind.continueLearning,
    );
  });

  test('starts learning when no evidence exists', () async {
    final insights = await _loadInsights(mastery: const [], reviews: const []);

    expect(
      insights.recommendation.kind,
      LearningRecommendationKind.startLearning,
    );
  });
}

Future<LearningInsights> _loadInsights({
  required List<Map<String, dynamic>> mastery,
  required List<Map<String, dynamic>> reviews,
}) async {
  final database = AppDatabase(factory: databaseFactoryFfi);
  await database.open(path: inMemoryDatabasePath);
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/mastery')) {
      return _json({'modelVersion': 1, 'items': mastery});
    }
    return _json({'generatedAt': '2026-07-30T00:00:00Z', 'items': reviews});
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
  try {
    return await service.load();
  } finally {
    client.close();
    await database.close();
  }
}

Map<String, dynamic> _mastery(String conceptId, double score) => {
  'conceptId': conceptId,
  'modelVersion': 1,
  'score': score,
  'correctEvidenceCount': score == 1 ? 1 : 0,
  'evidenceCount': 1,
  'lastEvidenceAt': '2026-07-30T00:00:00Z',
  'explanation': {'method': 'weighted-correct-ratio'},
};

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

import '../../../core/network/api_client.dart';
import '../../../core/network/api_problem.dart';
import '../../../core/storage/app_database.dart';
import 'learning_insights_models.dart';

class LearningInsightsService {
  LearningInsightsService(this._api, this._database);

  static const _cacheKey = 'learning.insights';

  final ApiClient _api;
  final AppDatabase _database;

  Future<LearningInsights> load() async {
    try {
      final responses = await Future.wait([
        _api.get('/api/mobile/v1/mastery', authenticated: true),
        _api.get(
          '/api/mobile/v1/reviews',
          authenticated: true,
          query: const {'limit': '20'},
        ),
      ]);
      final payload = {
        'mastery': responses[0]['items'],
        'reviews': responses[1]['items'],
      };
      await _database.cacheJson(_cacheKey, payload);
      return _decode(payload, fromCache: false);
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson(_cacheKey);
      if (cached == null) rethrow;
      return _decode(cached, fromCache: true);
    }
  }

  Future<LearningInsights> _decode(
    Map<String, dynamic> payload, {
    required bool fromCache,
  }) async => LearningInsights(
    mastery: (payload['mastery'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MasteryState.fromJson)
        .toList(growable: false),
    reviews: (payload['reviews'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReviewItem.fromJson)
        .toList(growable: false),
    pendingMutationCount: await _database.pendingMutationCount(),
    fromCache: fromCache,
  );

  bool _canUseCache(Object error) =>
      error is NetworkUnavailable || (error is ApiProblem && error.retryable);
}

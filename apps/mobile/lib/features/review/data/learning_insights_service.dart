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
  }) async {
    final mastery = (payload['mastery'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MasteryState.fromJson)
        .toList(growable: false);
    final reviews = (payload['reviews'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReviewItem.fromJson)
        .toList(growable: false);
    return LearningInsights(
      mastery: mastery,
      reviews: reviews,
      recommendation: _recommend(mastery, reviews),
      pendingMutationCount: await _database.pendingMutationCount(),
      fromCache: fromCache,
    );
  }

  LearningRecommendation _recommend(
    List<MasteryState> mastery,
    List<ReviewItem> reviews,
  ) {
    if (reviews.isNotEmpty) {
      final due = reviews.first;
      final matchingMastery = mastery
          .where((item) => item.conceptId == due.conceptId)
          .firstOrNull;
      return LearningRecommendation(
        algorithmVersion: 1,
        kind: LearningRecommendationKind.reviewDue,
        conceptId: due.conceptId,
        defaultLocale: due.defaultLocale,
        conceptTitle: due.title,
        masteryScore: matchingMastery?.score,
      );
    }
    if (mastery.isEmpty) {
      return const LearningRecommendation(
        algorithmVersion: 1,
        kind: LearningRecommendationKind.startLearning,
      );
    }
    final weakest = mastery.reduce((current, candidate) {
      if (candidate.score != current.score) {
        return candidate.score < current.score ? candidate : current;
      }
      return candidate.conceptId.compareTo(current.conceptId) < 0
          ? candidate
          : current;
    });
    if (weakest.score < 1) {
      return LearningRecommendation(
        algorithmVersion: 1,
        kind: LearningRecommendationKind.strengthenWeakConcept,
        conceptId: weakest.conceptId,
        defaultLocale: weakest.defaultLocale,
        conceptTitle: weakest.title,
        masteryScore: weakest.score,
      );
    }
    return const LearningRecommendation(
      algorithmVersion: 1,
      kind: LearningRecommendationKind.continueLearning,
    );
  }

  bool _canUseCache(Object error) =>
      error is NetworkUnavailable || (error is ApiProblem && error.retryable);
}

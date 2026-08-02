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
      Map<String, dynamic>? serverRecommendation;
      try {
        serverRecommendation = await _api.get(
          '/api/mobile/v1/recommendations/next',
          authenticated: true,
        );
      } on Object catch (error) {
        if (!_canUseCache(error)) rethrow;
      }
      final payload = {
        'mastery': responses[0]['items'],
        'reviews': responses[1]['items'],
      };
      if (serverRecommendation != null) {
        payload['recommendation'] = serverRecommendation;
      }
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
      recommendation: payload['recommendation'] is Map<String, dynamic>
          ? _serverRecommendation(
              payload['recommendation'] as Map<String, dynamic>,
              mastery,
              reviews,
            )
          : _recommend(mastery, reviews),
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
        explanationCode: 'LOCAL_REVIEW_DUE_FIRST',
        usedFallback: true,
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
        explanationCode: 'LOCAL_NO_LEARNING_EVIDENCE',
        usedFallback: true,
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
        explanationCode: 'LOCAL_LOWEST_MASTERY_FIRST',
        usedFallback: true,
        conceptId: weakest.conceptId,
        defaultLocale: weakest.defaultLocale,
        conceptTitle: weakest.title,
        masteryScore: weakest.score,
      );
    }
    return const LearningRecommendation(
      algorithmVersion: 1,
      kind: LearningRecommendationKind.continueLearning,
      explanationCode: 'LOCAL_NO_DUE_OR_WEAK_CONCEPT',
      usedFallback: true,
    );
  }

  LearningRecommendation _serverRecommendation(
    Map<String, dynamic> json,
    List<MasteryState> mastery,
    List<ReviewItem> reviews,
  ) {
    final kind = switch (json['kind']) {
      'review_due' => LearningRecommendationKind.reviewDue,
      'strengthen_weak_concept' =>
        LearningRecommendationKind.strengthenWeakConcept,
      'continue_learning' => LearningRecommendationKind.continueLearning,
      _ => LearningRecommendationKind.startLearning,
    };
    final conceptId = json['conceptId'] as String?;
    final masteryMatch = mastery.where((item) => item.conceptId == conceptId);
    final reviewMatch = reviews.where((item) => item.conceptId == conceptId);
    return LearningRecommendation(
      algorithmVersion: json['policyVersion'] as int,
      kind: kind,
      explanationCode: json['explanationCode'] as String,
      usedFallback: json['usedFallback'] as bool,
      conceptId: conceptId,
      defaultLocale:
          reviewMatch.firstOrNull?.defaultLocale ??
          masteryMatch.firstOrNull?.defaultLocale,
      conceptTitle:
          reviewMatch.firstOrNull?.title ?? masteryMatch.firstOrNull?.title,
      masteryScore: masteryMatch.firstOrNull?.score,
    );
  }

  bool _canUseCache(Object error) =>
      error is NetworkUnavailable || (error is ApiProblem && error.retryable);
}

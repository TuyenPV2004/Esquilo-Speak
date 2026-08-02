import 'package:flutter/foundation.dart';

import '../../../core/network/user_facing_failure.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../data/learning_insights_models.dart';
import '../data/learning_insights_service.dart';

class LearningInsightsViewModel extends ChangeNotifier {
  LearningInsightsViewModel(this._service, {this.telemetry});

  final LearningInsightsService _service;
  final ConsentAwareTelemetry? telemetry;

  LearningInsights? insights;
  UserFacingFailure? failure;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    failure = null;
    notifyListeners();
    try {
      insights = await _service.load();
      final recommendation = insights?.recommendation;
      if (recommendation != null && telemetry != null) {
        await telemetry!.event('recommendation_presented', {
          'recommendationPolicyVersion': recommendation.algorithmVersion,
          'recommendationKind': recommendation.kind.name,
          'reasonCode': recommendation.explanationCode,
          'usedFallback': recommendation.usedFallback,
        });
      }
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

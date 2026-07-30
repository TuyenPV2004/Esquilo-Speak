import 'package:flutter/foundation.dart';

import '../../../core/network/user_facing_failure.dart';
import '../data/learning_insights_models.dart';
import '../data/learning_insights_service.dart';

class LearningInsightsViewModel extends ChangeNotifier {
  LearningInsightsViewModel(this._service);

  final LearningInsightsService _service;

  LearningInsights? insights;
  UserFacingFailure? failure;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    failure = null;
    notifyListeners();
    try {
      insights = await _service.load();
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

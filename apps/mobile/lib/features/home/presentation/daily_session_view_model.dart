import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/user_facing_failure.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';
import '../../learning/presentation/learning_view_model.dart';
import '../../review/presentation/learning_insights_view_model.dart';
import '../data/daily_session_models.dart';

class DailySessionViewModel extends ChangeNotifier with WidgetsBindingObserver {
  DailySessionViewModel({
    required this.learning,
    required this.insights,
    required this.engagement,
    this._composer = const DailySessionComposer(),
    this._uuid = const Uuid(),
  }) {
    learning.addListener(_sourceChanged);
    insights.addListener(_sourceChanged);
    engagement.addListener(_sourceChanged);
    learning.onLearningCompleted = _handleLearningCompleted;
    WidgetsBinding.instance.addObserver(this);
  }

  final LearningViewModel learning;
  final LearningInsightsViewModel insights;
  final P1ViewModel engagement;
  final DailySessionComposer _composer;
  final Uuid _uuid;

  String? activePlanId;
  DailySessionPlan? activePlan;
  bool starting = false;

  DailySessionPlan? get plan {
    final currentInsights = insights.insights;
    final status = engagement.engagement;
    if (currentInsights == null || status == null) return null;
    return _composer.compose(
      lessons: learning.lessons,
      progress: learning.courseProgress,
      insights: currentInsights,
      unitDownloads: learning.unitDownloadStatuses,
      policy: status.dailyLearningPolicy,
    );
  }

  bool get loading =>
      starting ||
      (insights.loading && insights.insights == null) ||
      (engagement.busy && engagement.engagement == null) ||
      (learning.loading && learning.lessons.isEmpty);

  UserFacingFailure? get failure =>
      insights.failure ?? learning.error ?? engagement.failure;

  Future<void> refresh() async {
    if (activePlanId != null) await abandonActiveSession();
    await Future.wait([
      insights.load(),
      engagement.load(),
      learning.loadCatalog(),
    ]);
  }

  Future<bool> start() async {
    final selectedPlan = plan;
    if (selectedPlan == null || starting) return false;
    if (activePlanId != null) await abandonActiveSession();
    starting = true;
    activePlanId = _uuid.v4();
    activePlan = selectedPlan;
    notifyListeners();
    await _record('daily_session_started', selectedPlan);
    if (selectedPlan.kind == DailySessionKind.quickPractice) {
      final exerciseCount =
          engagement.engagement!.dailyLearningPolicy.quickPracticeExerciseCount;
      await learning.startQuickPractice(
        conceptIds: selectedPlan.conceptIds,
        exerciseCount: exerciseCount,
      );
    } else if (selectedPlan.lesson != null) {
      await learning.chooseLesson(selectedPlan.lesson!);
    }
    starting = false;
    notifyListeners();
    return learning.error == null;
  }

  Future<void> abandonActiveSession() async {
    final selectedPlan = activePlan;
    if (activePlanId == null || selectedPlan == null) return;
    await _record('daily_session_abandoned', selectedPlan);
    activePlanId = null;
    activePlan = null;
    notifyListeners();
  }

  Future<void> _handleLearningCompleted(LearningCompletion completion) async {
    if (completion.kind == LearningSessionKind.lesson) {
      await engagement.recordEngagementEvent(
        eventType: 'lesson_completed',
        evidenceRef: '${completion.courseId}:${completion.lessonId}',
      );
    }
    final selectedPlan = activePlan;
    if (activePlanId != null && selectedPlan != null) {
      await _record('daily_session_completed', selectedPlan);
      activePlanId = null;
      activePlan = null;
    }
    await insights.load();
    notifyListeners();
  }

  Future<void> _record(String eventType, DailySessionPlan selectedPlan) =>
      engagement.recordEngagementEvent(
        eventType: eventType,
        evidenceRef: '$activePlanId:${selectedPlan.source.name}',
      );

  void _sourceChanged() => notifyListeners();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(abandonActiveSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    learning.removeListener(_sourceChanged);
    insights.removeListener(_sourceChanged);
    engagement.removeListener(_sourceChanged);
    learning.onLearningCompleted = null;
    super.dispose();
  }
}

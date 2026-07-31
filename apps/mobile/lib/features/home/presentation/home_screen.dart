import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../../profile/presentation/learner_profile_view_model.dart';
import '../../review/data/learning_insights_models.dart';
import '../../review/presentation/learning_insights_view_model.dart';
import 'learning_recommendation_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.profileViewModel,
    required this.insightsViewModel,
    super.key,
  });

  final LearnerProfileViewModel profileViewModel;
  final LearningInsightsViewModel insightsViewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.todayTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: insightsViewModel,
            builder: (context, _) {
              if (insightsViewModel.loading &&
                  insightsViewModel.insights == null) {
                return AppLoadingState(label: strings.loadingProgress);
              }
              if (insightsViewModel.failure != null &&
                  insightsViewModel.insights == null) {
                return AppMessageState(
                  icon: Icons.cloud_off_outlined,
                  message: insightsViewModel.failure!.localized(strings),
                  actionLabel: strings.retry,
                  onAction: insightsViewModel.load,
                );
              }
              final insights = insightsViewModel.insights;
              final profile = profileViewModel.profile;
              final recommendation =
                  insights?.recommendation ??
                  const LearningRecommendation(
                    algorithmVersion: 1,
                    kind: LearningRecommendationKind.startLearning,
                  );
              final masteryAverage =
                  insights == null || insights.mastery.isEmpty
                  ? 0
                  : (insights.mastery
                                .map((item) => item.score)
                                .reduce((a, b) => a + b) /
                            insights.mastery.length *
                            100)
                        .round();
              return RefreshIndicator(
                onRefresh: insightsViewModel.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text(
                      strings.todayGreeting,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      strings.dailyGoalSummary(
                        profile?.preferences.dailyGoalMinutes ?? 10,
                      ),
                    ),
                    if (insights?.fromCache ?? false)
                      _StatusBanner(
                        icon: Icons.offline_bolt_outlined,
                        message: strings.showingOfflineData,
                      ),
                    if ((insights?.pendingMutationCount ?? 0) > 0)
                      _StatusBanner(
                        icon: Icons.sync_outlined,
                        message: strings.pendingSync(
                          insights!.pendingMutationCount,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    LearningRecommendationCard(
                      recommendation: recommendation,
                      onOpenLearning: () => context.go('/learn'),
                      onOpenReview: () => context.go('/review'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.event_repeat_outlined,
                            value: '${insights?.reviews.length ?? 0}',
                            label: strings.dueReviews,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.trending_up,
                            value: NumberFormat.percentPattern(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).format(masteryAverage / 100),
                            label: strings.mastery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/review'),
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: Text(strings.openReviewQueue),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonalIcon(
                      key: const ValueKey('advanced-learning-entry'),
                      onPressed: () => context.push('/home/advanced'),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(strings.openAdvancedLearning),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

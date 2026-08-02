import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../../advanced_learning/data/p1_models.dart';
import '../data/daily_session_models.dart';
import 'daily_session_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.dailySessionViewModel, super.key});

  final DailySessionViewModel dailySessionViewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.todayTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: dailySessionViewModel,
            builder: (context, _) {
              if (dailySessionViewModel.loading &&
                  dailySessionViewModel.plan == null) {
                return AppLoadingState(label: strings.loadingProgress);
              }
              final failure = dailySessionViewModel.failure;
              if (failure != null && dailySessionViewModel.plan == null) {
                return AppMessageState(
                  icon: Icons.cloud_off_outlined,
                  message: failure.localized(strings),
                  actionLabel: strings.retry,
                  onAction: dailySessionViewModel.refresh,
                );
              }
              final plan = dailySessionViewModel.plan;
              final insights = dailySessionViewModel.insights.insights;
              final engagement = dailySessionViewModel.engagement.engagement;
              if (plan == null || insights == null || engagement == null) {
                return AppMessageState(
                  icon: Icons.school_outlined,
                  message: strings.dailySessionUnavailable,
                  actionLabel: strings.retry,
                  onAction: dailySessionViewModel.refresh,
                );
              }
              return RefreshIndicator(
                onRefresh: dailySessionViewModel.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        strings.todayGreeting,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(strings.dailyHomeSubtitle),
                    if (insights.fromCache)
                      _StatusBanner(
                        icon: Icons.offline_bolt_outlined,
                        message: strings.showingOfflineData,
                      ),
                    if (insights.pendingMutationCount > 0)
                      _StatusBanner(
                        icon: Icons.sync_outlined,
                        message: strings.pendingSync(
                          insights.pendingMutationCount,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    _DailySessionCard(
                      plan: plan,
                      starting: dailySessionViewModel.starting,
                      onStart: () async {
                        final started = await dailySessionViewModel.start();
                        if (started && context.mounted) context.go('/learn');
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _GoalCard(goal: engagement.dailyGoal),
                    const SizedBox(height: AppSpacing.md),
                    _StreakCard(
                      current: engagement.currentStreak,
                      longest: engagement.longestStreak,
                    ),
                    if (plan.totalReviewCount > plan.visibleReviewCount) ...[
                      const SizedBox(height: AppSpacing.md),
                      _StatusBanner(
                        icon: Icons.filter_list_outlined,
                        message: strings.reviewBacklogLimited(
                          plan.visibleReviewCount,
                          plan.totalReviewCount,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/review'),
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: Text(strings.openReviewQueue),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
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

class _DailySessionCard extends StatelessWidget {
  const _DailySessionCard({
    required this.plan,
    required this.starting,
    required this.onStart,
  });

  final DailySessionPlan plan;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final (title, reason) = switch (plan.source) {
      DailySessionSource.dueReview => (
        strings.dailyReviewTitle,
        strings.dailyReviewReason(plan.visibleReviewCount),
      ),
      DailySessionSource.weakConcept => (
        strings.dailyWeakTitle,
        strings.dailyWeakReason,
      ),
      DailySessionSource.nextLesson => (
        strings.dailyNextLessonTitle,
        strings.dailyNextLessonReason,
      ),
      DailySessionSource.completedCourse => (
        strings.dailyMaintainTitle,
        strings.dailyMaintainReason,
      ),
      DailySessionSource.startLearning => (
        strings.recommendedStartTitle,
        strings.recommendedStartReason,
      ),
    };
    return Card(
      key: const ValueKey('daily-session-card'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(reason),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Chip(
                  avatar: const Icon(Icons.schedule_outlined),
                  label: Text(strings.minutesShort(plan.estimatedMinutes)),
                ),
                if (plan.offlineReady)
                  Chip(
                    avatar: const Icon(Icons.offline_pin_outlined),
                    label: Text(strings.availableOffline),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('daily-session-start'),
              onPressed: starting ? null : onStart,
              icon: starting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(strings.startDailySession),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final DailyGoalStatus goal;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final progress = goal.target == 0 ? 0.0 : goal.completed / goal.target;
    final unit = switch (goal.type) {
      'lessons' => strings.goalLessons,
      'reviews' => strings.goalReviews,
      _ => strings.goalMinutes,
    };
    final label = strings.dailyGoalProgress(goal.completed, goal.target, unit);
    return Card(
      key: const ValueKey('daily-goal-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(goal.achieved ? Icons.task_alt : Icons.flag_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    strings.dailyGoalTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              semanticsLabel: strings.dailyGoalTitle,
              semanticsValue: label,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('streak-card'),
      child: ListTile(
        leading: const Icon(Icons.local_fire_department_outlined),
        title: Text(strings.currentStreakValue(current)),
        subtitle: Text(strings.longestStreakValue(longest)),
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

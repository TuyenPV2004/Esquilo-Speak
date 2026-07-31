import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';

class EngagementScreen extends StatelessWidget {
  const EngagementScreen({required this.viewModel, super.key});

  final P1ViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(strings.engagementTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final status = viewModel.engagement;
              if (status == null) {
                return AppMessageState(
                  icon: Icons.local_fire_department_outlined,
                  message: strings.engagementLoading,
                  actionLabel: strings.retry,
                  onAction: viewModel.load,
                );
              }
              return ListView(
                key: const ValueKey('engagement-status'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  if (viewModel.permissionIssue ==
                      P1PermissionIssue.notifications)
                    _ErrorBanner(message: strings.notificationPermissionDenied),
                  if (viewModel.failure != null)
                    _ErrorBanner(
                      message: viewModel.failure!.localized(strings),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.local_fire_department_outlined,
                          value: '${status.currentStreak}',
                          label: strings.currentStreak,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Metric(
                          icon: Icons.stars_outlined,
                          value: '${status.xp}',
                          label: strings.experiencePoints,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: SwitchListTile(
                      key: const ValueKey('reminder-toggle'),
                      title: Text(strings.learningReminder),
                      subtitle: Text(
                        status.reminderTime ?? strings.reminderSchedule,
                      ),
                      value: status.reminderEnabled,
                      onChanged: viewModel.busy
                          ? null
                          : (enabled) => _changeReminder(
                              context,
                              status.reminderTime,
                              enabled,
                              locale,
                              strings,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('engagement-activity'),
                    onPressed: viewModel.busy
                        ? null
                        : viewModel.recordLearningActivity,
                    icon: const Icon(Icons.add_task),
                    label: Text(strings.completePractice),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.achievementsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (status.achievements.isEmpty)
                    Text(strings.noAchievements)
                  else
                    ...status.achievements.map(
                      (achievement) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.emoji_events_outlined),
                          title: Text(
                            achievement.code == 'first-step'
                                ? strings.firstStepAchievement
                                : achievement.code == 'seven-day-streak'
                                ? strings.sevenDayAchievement
                                : achievement.code,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _changeReminder(
    BuildContext context,
    String? currentValue,
    bool enabled,
    String locale,
    AppLocalizations strings,
  ) async {
    final currentParts = currentValue?.split(':');
    final initial = currentParts != null && currentParts.length >= 2
        ? TimeOfDay(
            hour: int.parse(currentParts[0]),
            minute: int.parse(currentParts[1]),
          )
        : TimeOfDay.now();
    final selected = enabled
        ? await showTimePicker(context: context, initialTime: initial)
        : initial;
    if (selected == null || !context.mounted) return;
    await viewModel.updateReminder(
      enabled: enabled,
      locale: locale,
      title: strings.reminderNotificationTitle,
      body: strings.reminderNotificationBody,
      hour: selected.hour,
      minute: selected.minute,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

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
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

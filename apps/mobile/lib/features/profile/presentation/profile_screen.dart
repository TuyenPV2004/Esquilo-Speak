import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/domain_state_localization.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../../../l10n/ui_locale_name.dart';
import '../../advanced_learning/data/p1_models.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';
import '../data/learner_profile_models.dart';
import '../../learning/data/learning_models.dart';
import 'learner_profile_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.viewModel,
    required this.engagementViewModel,
    this.languages = const [],
    super.key,
  });

  final LearnerProfileViewModel viewModel;
  final P1ViewModel engagementViewModel;
  final List<LearningLanguage> languages;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.profileTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: Listenable.merge([viewModel, engagementViewModel]),
            builder: (context, _) {
              if (viewModel.loading && viewModel.profile == null) {
                return AppLoadingState(label: strings.loadingProfile);
              }
              final profile = viewModel.profile;
              if (profile == null) {
                return AppMessageState(
                  icon: Icons.person_off_outlined,
                  message:
                      viewModel.failure?.localized(strings) ??
                      strings.profileUnavailable,
                  actionLabel: strings.retry,
                  onAction: viewModel.load,
                );
              }
              return ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          profile.actorType == LearnerActorType.guest
                              ? Icons.person_outline
                              : Icons.verified_user_outlined,
                        ),
                      ),
                      title: Text(
                        profile.actorType == LearnerActorType.guest
                            ? strings.guestLearner
                            : strings.accountLearner,
                      ),
                      subtitle: Text(
                        strings.languagePair(
                          _languageName(context, profile.sourceLanguage),
                          _languageName(context, profile.targetLanguage),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.learningPreferences,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.translate_outlined),
                          title: Text(strings.interfaceLanguage),
                          trailing: DropdownButton<String>(
                            key: const ValueKey('interface-language'),
                            value: _supportedUiLanguage(profile.uiLocale),
                            onChanged: viewModel.saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      viewModel.setUiLocale(value);
                                    }
                                  },
                            items: AppLocalizations.supportedLocales
                                .map(
                                  (locale) => DropdownMenuItem(
                                    value: locale.toLanguageTag(),
                                    child: UiLocaleName(locale),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(strings.dailyGoalTitle),
                          trailing: Text(
                            _goalLabel(strings, profile.preferences),
                          ),
                          onTap:
                              viewModel.saving ||
                                  engagementViewModel
                                          .engagement
                                          ?.dailyLearningPolicy ==
                                      null
                              ? null
                              : () => _editDailyGoal(
                                  context,
                                  profile.preferences,
                                  engagementViewModel
                                      .engagement!
                                      .dailyLearningPolicy,
                                ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: Text(strings.learningReminder),
                          trailing: Text(
                            profile.preferences.notificationsEnabled
                                ? strings.enabled
                                : strings.disabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.privacyTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(strings.operationalTelemetry),
                          subtitle: Text(strings.operationalTelemetryDetail),
                          value: viewModel.telemetryConsent,
                          onChanged: viewModel.saving
                              ? null
                              : viewModel.setTelemetryConsent,
                        ),
                        ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: Text(strings.exportData),
                          subtitle: Text(strings.exportDataDetail),
                          onTap: viewModel.saving
                              ? null
                              : viewModel.requestExport,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            strings.deleteAccount,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          subtitle: Text(strings.deleteAccountDetail),
                          onTap: viewModel.saving
                              ? null
                              : () => _confirmDeletion(context, strings),
                        ),
                      ],
                    ),
                  ),
                  if (viewModel.privacyRequest != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(strings.privacyRequestAccepted),
                            subtitle: Text(
                              strings.privacyRequestState(
                                localizedPrivacyState(
                                  strings,
                                  viewModel.privacyRequest!.state,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (viewModel.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          viewModel.failure!.localized(strings),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: viewModel.saving ? null : viewModel.logout,
                    icon: const Icon(Icons.logout),
                    label: Text(strings.logout),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _supportedUiLanguage(String? languageTag) {
    final requestedLanguage = languageTag?.split(RegExp('[-_]')).first;
    return AppLocalizations.supportedLocales
        .firstWhere(
          (locale) => locale.languageCode == requestedLanguage,
          orElse: () => AppLocalizations.supportedLocales.first,
        )
        .toLanguageTag();
  }

  String _languageName(BuildContext context, String? languageTag) {
    if (languageTag == null) return '—';
    for (final language in languages) {
      if (language.languageTag == languageTag) {
        return resolveLocalizedText(
          language.name,
          Localizations.localeOf(context).toLanguageTag(),
        );
      }
    }
    return languageTag;
  }

  String _goalLabel(AppLocalizations strings, LearnerPreferences preferences) {
    final unit = switch (preferences.dailyGoalType) {
      DailyGoalType.lessons => strings.goalLessons,
      DailyGoalType.reviews => strings.goalReviews,
      DailyGoalType.minutes => strings.goalMinutes,
    };
    return strings.dailyGoalSelection(preferences.dailyGoalTarget, unit);
  }

  Future<void> _editDailyGoal(
    BuildContext context,
    LearnerPreferences current,
    DailyLearningPolicy policy,
  ) async {
    var type = current.dailyGoalType;
    var target = current.dailyGoalTarget;
    final selected = await showDialog<(DailyGoalType, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final (minimum, maximum) = _goalRange(policy, type);
          target = target.clamp(minimum, maximum).toInt();
          final strings = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(strings.dailyGoalTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<DailyGoalType>(
                  key: const ValueKey('daily-goal-type'),
                  initialValue: type,
                  decoration: InputDecoration(labelText: strings.dailyGoalType),
                  items: DailyGoalType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(switch (item) {
                            DailyGoalType.minutes => strings.goalMinutes,
                            DailyGoalType.lessons => strings.goalLessons,
                            DailyGoalType.reviews => strings.goalReviews,
                          }),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      type = value;
                      final range = _goalRange(policy, type);
                      target = target.clamp(range.$1, range.$2).toInt();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(strings.dailyGoalTarget(target)),
                Slider(
                  key: const ValueKey('daily-goal-target'),
                  value: target.toDouble(),
                  min: minimum.toDouble(),
                  max: maximum.toDouble(),
                  divisions: maximum - minimum,
                  label: '$target',
                  onChanged: (value) => setState(() => target = value.round()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, (type, target)),
                child: Text(strings.saveGoal),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) {
      await viewModel.setDailyGoal(selected.$1, selected.$2);
    }
  }

  (int, int) _goalRange(DailyLearningPolicy policy, DailyGoalType type) =>
      switch (type) {
        DailyGoalType.minutes => (policy.minutesGoalMin, policy.minutesGoalMax),
        DailyGoalType.lessons => (policy.lessonsGoalMin, policy.lessonsGoalMax),
        DailyGoalType.reviews => (policy.reviewsGoalMin, policy.reviewsGoalMax),
      };

  Future<void> _confirmDeletion(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteAccountConfirmTitle),
        content: Text(strings.deleteAccountConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await viewModel.requestDeletion();
  }
}

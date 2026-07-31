import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../data/learner_profile_models.dart';
import 'learner_profile_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.viewModel, super.key});

  final LearnerProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.profileTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: viewModel,
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
                          profile.sourceLanguage?.toUpperCase() ?? '—',
                          profile.targetLanguage?.toUpperCase() ?? '—',
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
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(strings.dailyGoalTitle),
                          trailing: Text(
                            strings.minutes(
                              profile.preferences.dailyGoalMinutes,
                            ),
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
                                viewModel.privacyRequest!.state,
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

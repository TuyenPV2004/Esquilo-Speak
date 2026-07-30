import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../core/network/user_facing_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import 'learner_profile_view_model.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.viewModel, super.key});

  final LearnerProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ResponsiveContent(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final strings = AppLocalizations.of(context);
            if (viewModel.loading) {
              return AppLoadingState(label: strings.loadingProfile);
            }
            if (viewModel.failure != null) {
              final authenticationRequired =
                  viewModel.failure == UserFacingFailure.authenticationRequired;
              return AppMessageState(
                icon: Icons.cloud_off_outlined,
                message: viewModel.failure!.localized(strings),
                actionLabel: authenticationRequired
                    ? strings.signIn
                    : strings.retry,
                actionKey: ValueKey(
                  authenticationRequired ? 'sign-in' : 'retry-profile',
                ),
                onAction: authenticationRequired
                    ? viewModel.signIn
                    : viewModel.load,
              );
            }
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      strings.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(strings.welcomeMessage, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      key: const ValueKey('sign-in'),
                      onPressed: viewModel.saving ? null : viewModel.signIn,
                      icon: const Icon(Icons.login),
                      label: Text(strings.signInOrContinue),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

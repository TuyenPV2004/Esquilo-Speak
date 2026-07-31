import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../data/learner_profile_models.dart';
import 'learner_profile_view_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.viewModel, super.key});

  final LearnerProfileViewModel viewModel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  LearnerAgeBand? _ageBand;
  String _goal = 'daily_communication';
  int _dailyMinutes = 10;
  bool _notificationsEnabled = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final profile = widget.viewModel.profile;
    final accountUnder16 =
        profile?.actorType == LearnerActorType.account &&
        _ageBand == LearnerAgeBand.under16;
    return Scaffold(
      appBar: AppBar(title: Text(strings.onboardingTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => ListView(
              children: [
                Semantics(
                  label: strings.onboardingProgress,
                  value: '3/3',
                  child: const LinearProgressIndicator(value: 1),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  strings.onboardingHeading,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(strings.onboardingPrivacyNote),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  number: 1,
                  title: strings.ageBandTitle,
                  child: RadioGroup<LearnerAgeBand>(
                    key: const ValueKey('age-band'),
                    groupValue: _ageBand,
                    onChanged: (value) {
                      if (value != null) setState(() => _ageBand = value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<LearnerAgeBand>(
                          key: const ValueKey('age-under-16'),
                          value: LearnerAgeBand.under16,
                          title: Text(strings.ageUnder16),
                        ),
                        RadioListTile<LearnerAgeBand>(
                          key: const ValueKey('age-16-17'),
                          value: LearnerAgeBand.age16To17,
                          title: Text(strings.age16To17),
                        ),
                        RadioListTile<LearnerAgeBand>(
                          key: const ValueKey('age-adult'),
                          value: LearnerAgeBand.adult,
                          title: Text(strings.ageAdult),
                        ),
                        if (_submitted && _ageBand == null)
                          Semantics(
                            liveRegion: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                strings.ageBandRequired,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  number: 2,
                  title: strings.learningGoalTitle,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _goalChip(
                        'daily_communication',
                        strings.goalCommunication,
                      ),
                      _goalChip('work', strings.goalWork),
                      _goalChip('study', strings.goalStudy),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  number: 3,
                  title: strings.dailyGoalTitle,
                  child: Column(
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _minutesChip(5, strings.minutesShort(5)),
                          _minutesChip(10, strings.minutesShort(10)),
                          _minutesChip(15, strings.minutesShort(15)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(strings.learningReminder),
                        subtitle: Text(strings.learningReminderDescription),
                        value: _notificationsEnabled,
                        onChanged: (value) =>
                            setState(() => _notificationsEnabled = value),
                      ),
                    ],
                  ),
                ),
                if (accountUnder16)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        strings.guardianConsentRequired,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (widget.viewModel.failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.viewModel.failure!.localized(strings),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  key: const ValueKey('complete-onboarding'),
                  onPressed: widget.viewModel.saving || accountUnder16
                      ? null
                      : _complete,
                  child: Text(
                    widget.viewModel.saving
                        ? strings.saving
                        : strings.startLearning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _goal == value,
    onSelected: (_) => setState(() => _goal = value),
  );

  Widget _minutesChip(int value, String label) => ChoiceChip(
    label: Text(label),
    selected: _dailyMinutes == value,
    onSelected: (_) => setState(() => _dailyMinutes = value),
  );

  Future<void> _complete() async {
    setState(() => _submitted = true);
    final ageBand = _ageBand;
    if (ageBand == null) return;
    final completed = await widget.viewModel.completeOnboarding(
      ageBand: ageBand,
      learningGoal: _goal,
      dailyGoalMinutes: _dailyMinutes,
      notificationsEnabled: _notificationsEnabled,
    );
    if (completed && mounted) context.go('/home');
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$number. $title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

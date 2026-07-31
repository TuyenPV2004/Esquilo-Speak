import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../data/learner_profile_models.dart';
import 'learner_profile_view_model.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/presentation/learning_view_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.viewModel,
    required this.learningViewModel,
    super.key,
  });

  final LearnerProfileViewModel viewModel;
  final LearningViewModel learningViewModel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  LearnerAgeBand? _ageBand;
  String _goal = 'daily_communication';
  int _dailyMinutes = 10;
  bool _notificationsEnabled = false;
  bool _submitted = false;
  String? _sourceLanguage;
  String? _targetLanguage;
  Course? _activeCourse;

  @override
  void initState() {
    super.initState();
    if (widget.learningViewModel.languages.isEmpty) {
      widget.learningViewModel.loadCatalog();
    }
  }

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
                  value: '4/4',
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
                  title: strings.learningLanguagesTitle,
                  child: ListenableBuilder(
                    listenable: widget.learningViewModel,
                    builder: (context, _) => Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: const ValueKey('source-language'),
                          initialValue: _sourceLanguage,
                          decoration: InputDecoration(
                            labelText: strings.sourceLanguageTitle,
                          ),
                          items: _languageItems(context),
                          onChanged: (value) => _selectSourceLanguage(value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('target-language'),
                          initialValue: _targetLanguage,
                          decoration: InputDecoration(
                            labelText: strings.targetLanguageTitle,
                          ),
                          items: _languageItems(
                            context,
                            excluding: _sourceLanguage,
                          ),
                          onChanged: (value) => _selectTargetLanguage(value),
                        ),
                        if (widget.learningViewModel.courses.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<Course>(
                            key: const ValueKey('active-course'),
                            initialValue: _activeCourse,
                            decoration: InputDecoration(
                              labelText: strings.activeCourseTitle,
                            ),
                            items: widget.learningViewModel.courses
                                .map(
                                  (course) => DropdownMenuItem(
                                    value: course,
                                    child: Text(
                                      localized(
                                        course.title,
                                        Localizations.localeOf(
                                          context,
                                        ).languageCode,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (course) =>
                                setState(() => _activeCourse = course),
                          ),
                        ],
                        if (_submitted && !_hasLearningContext)
                          Semantics(
                            liveRegion: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                strings.learningContextRequired,
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
                  number: 3,
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
                  number: 4,
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

  bool get _hasLearningContext =>
      _sourceLanguage != null &&
      _targetLanguage != null &&
      _activeCourse != null;

  List<DropdownMenuItem<String>> _languageItems(
    BuildContext context, {
    String? excluding,
  }) => widget.learningViewModel.languages
      .where((language) => language.languageTag != excluding)
      .map(
        (language) => DropdownMenuItem(
          value: language.languageTag,
          child: Text(
            localized(
              language.name,
              Localizations.localeOf(context).languageCode,
            ),
          ),
        ),
      )
      .toList(growable: false);

  void _selectSourceLanguage(String? value) {
    setState(() {
      _sourceLanguage = value;
      if (_targetLanguage == value) _targetLanguage = null;
      _activeCourse = null;
    });
    _loadCourses();
  }

  void _selectTargetLanguage(String? value) {
    setState(() {
      _targetLanguage = value;
      _activeCourse = null;
    });
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final sourceLanguage = _sourceLanguage;
    final targetLanguage = _targetLanguage;
    if (sourceLanguage == null || targetLanguage == null) return;
    await widget.learningViewModel.loadCoursesFor(
      sourceLanguage,
      targetLanguage,
    );
    if (mounted && widget.learningViewModel.courses.length == 1) {
      setState(() => _activeCourse = widget.learningViewModel.courses.first);
    }
  }

  Future<void> _complete() async {
    setState(() => _submitted = true);
    final ageBand = _ageBand;
    final sourceLanguage = _sourceLanguage;
    final targetLanguage = _targetLanguage;
    final activeCourse = _activeCourse;
    if (ageBand == null ||
        sourceLanguage == null ||
        targetLanguage == null ||
        activeCourse == null) {
      return;
    }
    final completed = await widget.viewModel.completeOnboarding(
      ageBand: ageBand,
      uiLocale: Localizations.localeOf(context).toLanguageTag(),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      activeCourseId: activeCourse.id,
      learningGoal: _goal,
      dailyGoalMinutes: _dailyMinutes,
      notificationsEnabled: _notificationsEnabled,
    );
    if (completed) await widget.learningViewModel.loadCatalog();
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

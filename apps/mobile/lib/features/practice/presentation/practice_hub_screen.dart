import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../core/localization/localized_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../learning/presentation/learning_view_model.dart';
import '../../review/presentation/learning_insights_view_model.dart';
import '../data/practice_models.dart';

class PracticeHubScreen extends StatefulWidget {
  const PracticeHubScreen({
    required this.learning,
    required this.insights,
    super.key,
  });

  final LearningViewModel learning;
  final LearningInsightsViewModel insights;

  @override
  State<PracticeHubScreen> createState() => _PracticeHubScreenState();
}

class _PracticeHubScreenState extends State<PracticeHubScreen> {
  PracticeMode _mode = PracticeMode.flashcards;
  int _count = 5;
  String? _scopeValue;
  final Set<String> _types = {'multiple_choice', 'fill_blank'};
  int _shuffleSeed = 1;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scopes = _scopes(locale, strings);
    return Scaffold(
      appBar: AppBar(title: Text(strings.practiceTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: widget.learning,
            builder: (context, _) => ListView(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    strings.openPracticeModes,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(strings.practiceSubtitle),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: PracticeMode.values
                      .map(
                        (mode) => ChoiceChip(
                          key: ValueKey('practice-mode-${mode.apiValue}'),
                          selected: _mode == mode,
                          label: Text(_modeLabel(strings, mode)),
                          onSelected: (_) => setState(() {
                            _mode = mode;
                            if (mode == PracticeMode.match) _count = 3;
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('practice-scope'),
                  initialValue: _scopeValue,
                  decoration: InputDecoration(
                    labelText: strings.practiceScope,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.practiceAllContent),
                    ),
                    ...scopes.entries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _scopeValue = value),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_mode != PracticeMode.match) ...[
                  Text(strings.practiceQuestionCount(_count)),
                  Slider(
                    key: const ValueKey('practice-count'),
                    value: _count.toDouble(),
                    min: 3,
                    max: 20,
                    divisions: 17,
                    label: '$_count',
                    onChanged: (value) =>
                        setState(() => _count = value.round()),
                  ),
                ],
                if (_mode == PracticeMode.practiceTest) ...[
                  Text(
                    strings.practiceExerciseTypes,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children:
                        const [
                              'multiple_choice',
                              'listen_select',
                              'fill_blank',
                              'dictation',
                              'ordering',
                              'matching',
                            ]
                            .map((type) {
                              return FilterChip(
                                label: Text(_typeLabel(strings, type)),
                                selected: _types.contains(type),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _types.add(type);
                                  } else if (_types.length > 1) {
                                    _types.remove(type);
                                  }
                                }),
                              );
                            })
                            .toList(growable: false),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.offline_bolt_outlined),
                    title: Text(strings.practiceOfflineNotice),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('practice-start'),
                  onPressed: widget.learning.loading ? null : _start,
                  icon: widget.learning.loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(strings.startPractice),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final insights = widget.insights.insights;
    await widget.learning.startPractice(
      configuration: PracticeConfiguration(
        mode: _mode,
        count: _count,
        scope: _parseScope(_scopeValue),
        exerciseTypes: _mode == PracticeMode.practiceTest ? _types : const {},
        shuffleSeed: _shuffleSeed++,
      ),
      masteryByConcept: {
        for (final item in insights?.mastery ?? const [])
          item.conceptId: item.score,
      },
      dueConceptIds: {
        for (final item in insights?.reviews ?? const []) item.conceptId,
      },
    );
    if (mounted && widget.learning.error == null) context.go('/learn');
  }

  Map<String, String> _scopes(String locale, AppLocalizations strings) {
    final result = <String, String>{};
    for (final lesson in widget.learning.lessons) {
      if (lesson.unitId != null) {
        result['unit:${lesson.unitId}'] = strings.practiceScopeUnit(
          resolveLocalizedText(
            lesson.unitTitle,
            locale,
            defaultLocale: lesson.locale,
          ),
        );
      }
      result['lesson:${lesson.id}'] = strings.practiceScopeLesson(
        resolveLocalizedText(
          lesson.title,
          locale,
          defaultLocale: lesson.locale,
        ),
      );
    }
    for (final mastery in widget.insights.insights?.mastery ?? const []) {
      result['concept:${mastery.conceptId}'] = strings.practiceScopeConcept(
        resolveLocalizedText(
          mastery.title,
          locale,
          defaultLocale: mastery.defaultLocale,
        ),
      );
    }
    return result;
  }

  PracticeScope? _parseScope(String? value) {
    if (value == null) return null;
    final separator = value.indexOf(':');
    final kind = value.substring(0, separator);
    return PracticeScope(
      kind: switch (kind) {
        'unit' => PracticeScopeKind.unit,
        'lesson' => PracticeScopeKind.lesson,
        _ => PracticeScopeKind.concept,
      },
      id: value.substring(separator + 1),
    );
  }

  String _modeLabel(AppLocalizations strings, PracticeMode mode) =>
      switch (mode) {
        PracticeMode.flashcards => strings.practiceFlashcards,
        PracticeMode.adaptiveLearn => strings.practiceAdaptive,
        PracticeMode.practiceTest => strings.practiceTest,
        PracticeMode.match => strings.practiceMatch,
        PracticeMode.mistakes => strings.practiceMistakes,
        PracticeMode.weakConcepts => strings.practiceWeak,
      };

  String _typeLabel(AppLocalizations strings, String type) => switch (type) {
    'multiple_choice' => strings.practiceTypeMultipleChoice,
    'listen_select' => strings.practiceTypeListenSelect,
    'fill_blank' => strings.practiceTypeFillBlank,
    'dictation' => strings.practiceTypeDictation,
    'ordering' => strings.practiceTypeOrdering,
    _ => strings.practiceTypeMatching,
  };
}

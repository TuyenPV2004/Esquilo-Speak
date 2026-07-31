import 'package:flutter/material.dart';

import '../data/learning_models.dart';

typedef ExerciseRendererBuilder =
    Widget Function(
      Lesson lesson,
      Exercise exercise,
      String? selectedOptionId,
      String? selectionError,
      ValueChanged<String> onSelected,
      VoidCallback onSubmit,
      String submitLabel,
    );

class ExerciseRendererRegistry extends StatelessWidget {
  const ExerciseRendererRegistry({
    required this.lesson,
    required this.selectedOptionId,
    required this.selectionError,
    required this.onSelected,
    required this.onSubmit,
    required this.submitLabel,
    required this.unsupportedLabel,
    super.key,
  });

  static final Map<String, ExerciseRendererBuilder> _renderers = {
    'multiple_choice': _optionRenderer,
    'true_false': _optionRenderer,
  };

  final Lesson lesson;
  final String? selectedOptionId;
  final String? selectionError;
  final ValueChanged<String> onSelected;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String unsupportedLabel;

  @override
  Widget build(BuildContext context) {
    final exercise = lesson.exercises.first;
    final renderer = _renderers[exercise.type];
    if (renderer == null) {
      return Center(child: Text(unsupportedLabel));
    }
    return renderer(
      lesson,
      exercise,
      selectedOptionId,
      selectionError,
      onSelected,
      onSubmit,
      submitLabel,
    );
  }

  static Widget _optionRenderer(
    Lesson lesson,
    Exercise exercise,
    String? selectedOptionId,
    String? selectionError,
    ValueChanged<String> onSelected,
    VoidCallback onSubmit,
    String submitLabel,
  ) => _OptionExerciseRenderer(
    lesson: lesson,
    exercise: exercise,
    selectedOptionId: selectedOptionId,
    selectionError: selectionError,
    onSelected: onSelected,
    onSubmit: onSubmit,
    submitLabel: submitLabel,
  );
}

class _OptionExerciseRenderer extends StatelessWidget {
  const _OptionExerciseRenderer({
    required this.lesson,
    required this.exercise,
    required this.selectedOptionId,
    required this.selectionError,
    required this.onSelected,
    required this.onSubmit,
    required this.submitLabel,
  });

  final Lesson lesson;
  final Exercise exercise;
  final String? selectedOptionId;
  final String? selectionError;
  final ValueChanged<String> onSelected;
  final VoidCallback onSubmit;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      key: const ValueKey('lesson'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          localized(lesson.title, locale, defaultLocale: lesson.locale),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          localized(
            lesson.objectives.first,
            locale,
            defaultLocale: lesson.locale,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          localized(exercise.prompt, locale, defaultLocale: lesson.locale),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: selectedOptionId,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          child: Column(
            children: exercise.options
                .map(
                  (option) => Semantics(
                    selected: selectedOptionId == option.id,
                    child: RadioListTile<String>(
                      key: ValueKey('option-${option.id}'),
                      value: option.id,
                      title: Text(
                        localized(
                          option.text,
                          locale,
                          defaultLocale: lesson.locale,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (selectionError != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                selectionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('attempt-submit'),
          onPressed: onSubmit,
          child: Text(submitLabel),
        ),
      ],
    );
  }
}

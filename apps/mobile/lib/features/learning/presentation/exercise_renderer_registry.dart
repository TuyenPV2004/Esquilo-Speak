import 'package:flutter/material.dart';

import '../data/learning_models.dart';

typedef ExerciseRendererBuilder = Widget Function(ExerciseRenderContext data);

class ExerciseRenderContext {
  const ExerciseRenderContext({
    required this.lesson,
    required this.exercise,
    required this.exerciseIndex,
    required this.response,
    required this.selectionError,
    required this.hintVisible,
    required this.onResponse,
    required this.onHint,
    required this.onSubmit,
    required this.submitLabel,
    required this.hintLabel,
    required this.knowLabel,
    required this.learningLabel,
    required this.moveUpLabel,
    required this.moveDownLabel,
  });

  final Lesson lesson;
  final Exercise exercise;
  final int exerciseIndex;
  final ExerciseResponse? response;
  final String? selectionError;
  final bool hintVisible;
  final ValueChanged<ExerciseResponse> onResponse;
  final VoidCallback onHint;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String hintLabel;
  final String knowLabel;
  final String learningLabel;
  final String moveUpLabel;
  final String moveDownLabel;
}

class ExerciseRendererRegistry extends StatelessWidget {
  const ExerciseRendererRegistry({
    required this.lesson,
    required this.exerciseIndex,
    required this.response,
    required this.selectionError,
    required this.hintVisible,
    required this.onResponse,
    required this.onHint,
    required this.onSubmit,
    required this.submitLabel,
    required this.hintLabel,
    required this.knowLabel,
    required this.learningLabel,
    required this.moveUpLabel,
    required this.moveDownLabel,
    required this.unsupportedLabel,
    super.key,
  });

  static final Map<String, ExerciseRendererBuilder> _renderers = {
    'multiple_choice': _optionRenderer,
    'true_false': _optionRenderer,
    'listen_select': _optionRenderer,
    'comprehension': _optionRenderer,
    'flashcard': _flashcardRenderer,
    'matching': _matchingRenderer,
    'ordering': _orderingRenderer,
    'fill_blank': _textRenderer,
    'dictation': _textRenderer,
  };

  final Lesson lesson;
  final int exerciseIndex;
  final ExerciseResponse? response;
  final String? selectionError;
  final bool hintVisible;
  final ValueChanged<ExerciseResponse> onResponse;
  final VoidCallback onHint;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String hintLabel;
  final String knowLabel;
  final String learningLabel;
  final String moveUpLabel;
  final String moveDownLabel;
  final String unsupportedLabel;

  @override
  Widget build(BuildContext context) {
    final exercise = lesson.exercises[exerciseIndex];
    final renderer = _renderers[exercise.type];
    if (renderer == null) return Center(child: Text(unsupportedLabel));
    final data = ExerciseRenderContext(
      lesson: lesson,
      exercise: exercise,
      exerciseIndex: exerciseIndex,
      response: response,
      selectionError: selectionError,
      hintVisible: hintVisible,
      onResponse: onResponse,
      onHint: onHint,
      onSubmit: onSubmit,
      submitLabel: submitLabel,
      hintLabel: hintLabel,
      knowLabel: knowLabel,
      learningLabel: learningLabel,
      moveUpLabel: moveUpLabel,
      moveDownLabel: moveDownLabel,
    );
    return _ExerciseFrame(data: data, child: renderer(data));
  }

  static Widget _optionRenderer(ExerciseRenderContext data) {
    final selected = switch (data.response) {
      OptionExerciseResponse response => response.optionId,
      BooleanExerciseResponse response => response.value.toString(),
      _ => null,
    };
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (value == null) return;
        data.onResponse(
          data.exercise.type == 'true_false'
              ? BooleanExerciseResponse(value == 'true')
              : OptionExerciseResponse(value),
        );
      },
      child: Column(
        children: data.exercise.options
            .map(
              (option) => Semantics(
                selected: selected == option.id,
                child: RadioListTile<String>(
                  key: ValueKey('option-${option.id}'),
                  value: option.id,
                  title: Text(_text(data, option.text)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static Widget _flashcardRenderer(ExerciseRenderContext data) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          key: const ValueKey('flashcard-learning'),
          onPressed: () =>
              data.onResponse(const SelfAssessmentExerciseResponse('learning')),
          child: Text(data.learningLabel),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.tonal(
          key: const ValueKey('flashcard-know'),
          onPressed: () =>
              data.onResponse(const SelfAssessmentExerciseResponse('know')),
          child: Text(data.knowLabel),
        ),
      ),
    ],
  );

  static Widget _textRenderer(ExerciseRenderContext data) => TextFormField(
    key: ValueKey('text-${data.exercise.id}'),
    initialValue: switch (data.response) {
      TextExerciseResponse response => response.text,
      _ => null,
    },
    minLines: 1,
    maxLines: 3,
    textInputAction: TextInputAction.done,
    onChanged: (value) => data.onResponse(TextExerciseResponse(value)),
    onFieldSubmitted: (_) => data.onSubmit(),
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      errorText: data.selectionError,
    ),
  );

  static Widget _orderingRenderer(ExerciseRenderContext data) {
    final ids = switch (data.response) {
      SequenceExerciseResponse response => [...response.itemIds],
      _ => data.exercise.items.map((item) => item.id).toList(),
    };
    final byId = {for (final item in data.exercise.items) item.id: item};
    return Column(
      children: [
        for (var index = 0; index < ids.length; index++)
          ListTile(
            key: ValueKey('order-${ids[index]}'),
            leading: Text('${index + 1}'),
            title: Text(_text(data, byId[ids[index]]!.text)),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: data.moveUpLabel,
                  onPressed: index == 0
                      ? null
                      : () => data.onResponse(
                          SequenceExerciseResponse(
                            _moved(ids, index, index - 1),
                          ),
                        ),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: data.moveDownLabel,
                  onPressed: index == ids.length - 1
                      ? null
                      : () => data.onResponse(
                          SequenceExerciseResponse(
                            _moved(ids, index, index + 1),
                          ),
                        ),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static List<String> _moved(List<String> source, int from, int to) {
    final result = [...source];
    final value = result.removeAt(from);
    result.insert(to, value);
    return result;
  }

  static Widget _matchingRenderer(ExerciseRenderContext data) {
    final selected = {
      for (final pair in switch (data.response) {
        PairExerciseResponse response => response.pairs,
        _ => const <ExercisePair>[],
      })
        pair.leftId: pair.rightId,
    };
    return Column(
      children: data.exercise.leftItems.map((left) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('match-${left.id}'),
            initialValue: selected[left.id],
            decoration: InputDecoration(
              labelText: _text(data, left.text),
              border: const OutlineInputBorder(),
            ),
            items: data.exercise.rightItems
                .map(
                  (right) => DropdownMenuItem(
                    value: right.id,
                    child: Text(_text(data, right.text)),
                  ),
                )
                .toList(),
            onChanged: (rightId) {
              if (rightId == null) return;
              selected[left.id] = rightId;
              data.onResponse(
                PairExerciseResponse([
                  for (final entry in selected.entries)
                    ExercisePair(leftId: entry.key, rightId: entry.value),
                ]),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  static String _text(ExerciseRenderContext data, LocalizedText values) {
    final locale = data.lesson.locale;
    return localized(values, locale ?? 'en', defaultLocale: locale);
  }
}

class _ExerciseFrame extends StatelessWidget {
  const _ExerciseFrame({required this.data, required this.child});

  final ExerciseRenderContext data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    String content(LocalizedText values) =>
        localized(values, locale, defaultLocale: data.lesson.locale);
    return ListView(
      key: ValueKey('exercise-${data.exercise.id}'),
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          label: '${data.exerciseIndex + 1}/${data.lesson.exercises.length}',
          child: LinearProgressIndicator(
            value: (data.exerciseIndex + 1) / data.lesson.exercises.length,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          content(data.lesson.title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        if (data.exercise.instruction.isNotEmpty) ...[
          Text(content(data.exercise.instruction)),
          const SizedBox(height: 8),
        ],
        Text(
          content(data.exercise.prompt),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data.exercise.transcript.isNotEmpty &&
            (data.exercise.type != 'dictation' || data.hintVisible)) ...[
          const SizedBox(height: 12),
          Semantics(
            label: content(data.exercise.transcript),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(content(data.exercise.transcript)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
        if (data.exercise.hint.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('show-hint'),
            onPressed: data.onHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(data.hintLabel),
          ),
          if (data.hintVisible)
            Semantics(
              liveRegion: true,
              child: Text(content(data.exercise.hint)),
            ),
        ],
        if (data.selectionError != null &&
            data.exercise.type != 'fill_blank' &&
            data.exercise.type != 'dictation')
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                data.selectionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('attempt-submit'),
          onPressed: data.onSubmit,
          child: Text(data.submitLabel),
        ),
      ],
    );
  }
}

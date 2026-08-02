import '../../learning/data/learning_models.dart';

enum PracticeMode {
  flashcards('flashcards'),
  adaptiveLearn('adaptive_learn'),
  practiceTest('practice_test'),
  match('match'),
  mistakes('mistakes'),
  weakConcepts('weak_concepts');

  const PracticeMode(this.apiValue);
  final String apiValue;
}

enum PracticeScopeKind { unit, lesson, concept }

class PracticeScope {
  const PracticeScope({required this.kind, required this.id});

  final PracticeScopeKind kind;
  final String id;
}

class PracticeCandidate {
  const PracticeCandidate({
    required this.lesson,
    required this.exercise,
    this.unitId,
  });

  final Lesson lesson;
  final Exercise exercise;
  final String? unitId;
}

class PracticeConfiguration {
  const PracticeConfiguration({
    required this.mode,
    required this.count,
    this.scope,
    this.exerciseTypes = const <String>{},
    this.shuffleSeed = 1,
  });

  final PracticeMode mode;
  final int count;
  final PracticeScope? scope;
  final Set<String> exerciseTypes;
  final int shuffleSeed;
}

class PracticeSelection {
  const PracticeSelection({
    required this.items,
    required this.explanationCode,
    required this.usedFallback,
  });

  final List<PracticeCandidate> items;
  final String explanationCode;
  final bool usedFallback;
}

class PracticeSelector {
  const PracticeSelector();

  PracticeSelection select({
    required PracticeConfiguration configuration,
    required List<PracticeCandidate> candidates,
    Map<String, double> masteryByConcept = const {},
    Set<String> dueConceptIds = const {},
    Set<String> recentMistakeExerciseIds = const {},
  }) {
    final scoped = candidates
        .where((candidate) {
          final scope = configuration.scope;
          if (scope == null) return true;
          return switch (scope.kind) {
            PracticeScopeKind.unit => candidate.unitId == scope.id,
            PracticeScopeKind.lesson => candidate.lesson.id == scope.id,
            PracticeScopeKind.concept => candidate.exercise.conceptIds.contains(
              scope.id,
            ),
          };
        })
        .toList(growable: false);
    final source = scoped.isEmpty ? candidates : scoped;
    var usedFallback = scoped.isEmpty && configuration.scope != null;
    List<PracticeCandidate> preferred;
    String explanation;

    switch (configuration.mode) {
      case PracticeMode.flashcards:
        preferred = source
            .where((item) => item.exercise.type == 'flashcard')
            .toList();
        explanation = 'practice_reason_flashcards';
      case PracticeMode.adaptiveLearn:
        preferred = [...source]
          ..sort((left, right) {
            final leftScore = _score(left, masteryByConcept);
            final rightScore = _score(right, masteryByConcept);
            final scoreOrder = leftScore.compareTo(rightScore);
            if (scoreOrder != 0) return scoreOrder;
            final leftStage = _adaptiveStage(left.exercise.type, leftScore);
            final rightStage = _adaptiveStage(right.exercise.type, rightScore);
            final stageOrder = leftStage.compareTo(rightStage);
            return stageOrder != 0
                ? stageOrder
                : left.exercise.id.compareTo(right.exercise.id);
          });
        explanation = 'practice_reason_adaptive';
      case PracticeMode.practiceTest:
        preferred = source
            .where(
              (item) =>
                  configuration.exerciseTypes.isEmpty ||
                  configuration.exerciseTypes.contains(item.exercise.type),
            )
            .toList();
        explanation = 'practice_reason_test';
      case PracticeMode.match:
        preferred = source
            .where((item) => item.exercise.type == 'matching')
            .toList();
        explanation = 'practice_reason_match';
      case PracticeMode.mistakes:
        preferred = source
            .where(
              (item) => recentMistakeExerciseIds.contains(item.exercise.id),
            )
            .toList();
        explanation = 'practice_reason_mistakes';
      case PracticeMode.weakConcepts:
        preferred = [...source]
          ..sort((left, right) {
            final leftDue = left.exercise.conceptIds.any(
              dueConceptIds.contains,
            );
            final rightDue = right.exercise.conceptIds.any(
              dueConceptIds.contains,
            );
            if (leftDue != rightDue) return leftDue ? -1 : 1;
            final scoreOrder = _score(
              left,
              masteryByConcept,
            ).compareTo(_score(right, masteryByConcept));
            return scoreOrder != 0
                ? scoreOrder
                : left.exercise.id.compareTo(right.exercise.id);
          });
        explanation = 'practice_reason_weak';
    }

    if (preferred.isEmpty) {
      preferred = [...source];
      usedFallback = true;
      explanation = 'practice_reason_fallback';
    }
    if (configuration.mode == PracticeMode.flashcards ||
        configuration.mode == PracticeMode.practiceTest) {
      preferred = _shuffled(preferred, configuration.shuffleSeed);
    }
    final limit = configuration.mode == PracticeMode.match
        ? configuration.count.clamp(1, 3)
        : configuration.count.clamp(1, 20);
    return PracticeSelection(
      items: preferred.take(limit).toList(growable: false),
      explanationCode: explanation,
      usedFallback: usedFallback,
    );
  }

  double _score(
    PracticeCandidate candidate,
    Map<String, double> masteryByConcept,
  ) {
    final values = candidate.exercise.conceptIds
        .map((id) => masteryByConcept[id])
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  int _adaptiveStage(String type, double score) {
    const recognition = {'multiple_choice', 'true_false', 'listen_select'};
    const recall = {'fill_blank', 'dictation', 'ordering'};
    if (score < 0.65) return recognition.contains(type) ? 0 : 1;
    return recall.contains(type) ? 0 : 1;
  }

  List<PracticeCandidate> _shuffled(List<PracticeCandidate> source, int seed) {
    final result = [...source];
    var state = seed == 0 ? 1 : seed;
    for (var index = result.length - 1; index > 0; index--) {
      state ^= state << 13;
      state ^= state >> 17;
      state ^= state << 5;
      final swapIndex = (state & 0x7fffffff) % (index + 1);
      final value = result[index];
      result[index] = result[swapIndex];
      result[swapIndex] = value;
    }
    return result;
  }
}

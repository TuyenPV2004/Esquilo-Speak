import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/practice/data/practice_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const selector = PracticeSelector();
  final lesson = Lesson(
    id: 'lesson-1',
    courseId: 'course-1',
    version: 2,
    title: const {'en': 'Lesson'},
    objectives: const [],
    exercises: const [],
  );
  const shared = Exercise(
    id: 'shared-item',
    type: 'flashcard',
    prompt: {'en': 'Hello'},
    conceptIds: ['concept-1'],
  );
  const recognition = Exercise(
    id: 'recognition',
    type: 'multiple_choice',
    prompt: {'en': 'Choose'},
    conceptIds: ['concept-1'],
  );
  const recall = Exercise(
    id: 'recall',
    type: 'fill_blank',
    prompt: {'en': 'Write'},
    conceptIds: ['concept-1'],
  );
  final candidates = [
    PracticeCandidate(lesson: lesson, exercise: shared, unitId: 'unit-1'),
    PracticeCandidate(lesson: lesson, exercise: recognition, unitId: 'unit-1'),
    PracticeCandidate(lesson: lesson, exercise: recall, unitId: 'unit-1'),
  ];

  test('selection is deterministic for the same seed and explanation', () {
    const configuration = PracticeConfiguration(
      mode: PracticeMode.practiceTest,
      count: 3,
      shuffleSeed: 42,
    );

    final first = selector.select(
      configuration: configuration,
      candidates: candidates,
    );
    final second = selector.select(
      configuration: configuration,
      candidates: candidates,
    );

    expect(
      first.items.map((item) => item.exercise.id),
      second.items.map((item) => item.exercise.id),
    );
    expect(first.explanationCode, 'practice_reason_test');
  });

  test('adaptive learn moves from recognition to recall using mastery', () {
    final low = selector.select(
      configuration: const PracticeConfiguration(
        mode: PracticeMode.adaptiveLearn,
        count: 3,
      ),
      candidates: candidates,
      masteryByConcept: const {'concept-1': 0.2},
    );
    final high = selector.select(
      configuration: const PracticeConfiguration(
        mode: PracticeMode.adaptiveLearn,
        count: 3,
      ),
      candidates: candidates,
      masteryByConcept: const {'concept-1': 0.9},
    );

    expect(low.items.first.exercise.id, 'recognition');
    expect(high.items.first.exercise.id, 'recall');
  });

  test('one canonical learning item is reused by three modes', () {
    PracticeCandidate selected(PracticeMode mode) => selector
        .select(
          configuration: PracticeConfiguration(
            mode: mode,
            count: 3,
            exerciseTypes: const {'flashcard'},
          ),
          candidates: candidates,
          recentMistakeExerciseIds: const {'shared-item'},
        )
        .items
        .firstWhere((item) => item.exercise.id == 'shared-item');

    final flashcard = selected(PracticeMode.flashcards);
    final testItem = selected(PracticeMode.practiceTest);
    final mistake = selected(PracticeMode.mistakes);

    expect(identical(flashcard.exercise, shared), isTrue);
    expect(identical(testItem.exercise, shared), isTrue);
    expect(identical(mistake.exercise, shared), isTrue);
    expect(flashcard.lesson.version, 2);
    expect(testItem.lesson.id, flashcard.lesson.id);
  });

  test('match rounds are limited and missing scope reports fallback', () {
    final selection = selector.select(
      configuration: const PracticeConfiguration(
        mode: PracticeMode.match,
        count: 20,
        scope: PracticeScope(kind: PracticeScopeKind.unit, id: 'missing'),
      ),
      candidates: candidates,
    );

    expect(selection.items.length, lessThanOrEqualTo(3));
    expect(selection.usedFallback, isTrue);
    expect(selection.explanationCode, 'practice_reason_fallback');
  });
}

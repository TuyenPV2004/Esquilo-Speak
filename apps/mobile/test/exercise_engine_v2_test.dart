import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/exercise_renderer_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all V2 response kinds round-trip and evidence stays UI-independent',
    () {
      const responses = <ExerciseResponse>[
        OptionExerciseResponse('option-a'),
        BooleanExerciseResponse(true),
        SelfAssessmentExerciseResponse('learning'),
        TextExerciseResponse('Hello'),
        SequenceExerciseResponse(['item-a', 'item-b']),
        PairExerciseResponse([
          ExercisePair(leftId: 'left-a', rightId: 'right-a'),
        ]),
      ];
      for (final response in responses) {
        expect(
          ExerciseResponse.fromJson(response.toJson()).toJson(),
          response.toJson(),
        );
      }
      final payload = PendingAttempt(
        clientAttemptId: '11111111-1111-4111-8111-111111111111',
        clientMutationId: '22222222-2222-4222-8222-222222222222',
        idempotencyKey: '33333333-3333-4333-8333-333333333333',
        courseId: 'course-test',
        lessonId: 'lesson-test',
        lessonVersion: 2,
        exerciseId: 'exercise-test',
        response: responses.last,
        occurredAt: DateTime.utc(2026, 8, 1),
        evidence: const AttemptEvidence(
          responseTimeMs: 1250,
          hintUsed: true,
          hintLevel: 1,
          retryIndex: 2,
          confidence: 4,
          inputModality: 'assistive_technology',
        ),
      ).toJson();
      expect(payload['response'], responses.last.toJson());
      expect(payload['evidence'], {
        'responseTimeMs': 1250,
        'hintUsed': true,
        'hintLevel': 1,
        'retryIndex': 2,
        'confidence': 4,
        'inputModality': 'assistive_technology',
      });
    },
  );

  testWidgets(
    'registry renders option, flashcard, text, ordering and matching families',
    (tester) async {
      for (final exercise in _exercises) {
        ExerciseResponse? response;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: ExerciseRendererRegistry(
                  lesson: _lesson(exercise),
                  exerciseIndex: 0,
                  response: response,
                  selectionError: null,
                  hintVisible: false,
                  onResponse: (value) => response = value,
                  onHint: () {},
                  onSubmit: () {},
                  submitLabel: 'Submit',
                  hintLabel: 'Hint',
                  knowLabel: 'Know',
                  learningLabel: 'Learning',
                  moveUpLabel: 'Move up',
                  moveDownLabel: 'Move down',
                  unsupportedLabel: 'Unsupported',
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(ValueKey('exercise-${exercise.id}')), findsOneWidget);
        expect(find.text('Unsupported'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('dictation transcript is an explicit silent-mode hint', (
    tester,
  ) async {
    const exercise = Exercise(
      id: 'exercise-dictation-hint',
      type: 'dictation',
      prompt: {'en': 'Type what you hear.'},
      hint: {'en': 'Use the transcript in silent mode.'},
      transcript: {'en': 'Hello'},
    );

    Future<void> pump({required bool hintVisible}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseRendererRegistry(
            lesson: _lesson(exercise),
            exerciseIndex: 0,
            response: null,
            selectionError: null,
            hintVisible: hintVisible,
            onResponse: (_) {},
            onHint: () {},
            onSubmit: () {},
            submitLabel: 'Submit',
            hintLabel: 'Hint',
            knowLabel: 'Know',
            learningLabel: 'Learning',
            moveUpLabel: 'Move up',
            moveDownLabel: 'Move down',
            unsupportedLabel: 'Unsupported',
          ),
        ),
      ),
    );

    await pump(hintVisible: false);
    expect(find.text('Hello'), findsNothing);
    await pump(hintVisible: true);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('flashcard works with buttons, audio and 200% text', (
    tester,
  ) async {
    const exercise = Exercise(
      id: 'exercise-flashcard-accessible',
      type: 'flashcard',
      prompt: {'en': 'Recall Hello.'},
      hint: {'en': 'Hello means a greeting.'},
      mediaId: 'media-hello',
    );
    var revealed = false;
    var played = false;
    ExerciseResponse? response;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ExerciseRendererRegistry(
                lesson: _lesson(exercise),
                exerciseIndex: 0,
                response: response,
                selectionError: null,
                hintVisible: false,
                onResponse: (value) => response = value,
                onHint: () {},
                onSubmit: () {},
                submitLabel: 'Submit',
                hintLabel: 'Hint',
                knowLabel: 'Know',
                learningLabel: 'Learning',
                moveUpLabel: 'Move up',
                moveDownLabel: 'Move down',
                unsupportedLabel: 'Unsupported',
                flashcardRevealed: revealed,
                onFlashcardFlip: () => setState(() => revealed = !revealed),
                flipCardLabel: 'Reveal card',
                cardBackLabel: 'Card answer',
                playAudioLabel: 'Play audio',
                onPlayAudio: () => played = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('flashcard-learning')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('flashcard-flip')));
    await tester.pump();
    expect(find.text('Hello means a greeting.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flashcard-audio')));
    await tester.tap(find.byKey(const ValueKey('flashcard-know')));
    expect(played, isTrue);
    expect(response?.toJson(), {'kind': 'self_assessment', 'value': 'know'});
    expect(tester.takeException(), isNull);
  });
}

Lesson _lesson(Exercise exercise) => Lesson(
  id: 'lesson-engine-v2',
  courseId: 'course-engine-v2',
  version: 2,
  locale: 'en',
  title: const {'en': 'Engine V2'},
  objectives: const [
    {'en': 'Complete the exercise.'},
  ],
  exercises: [exercise],
);

const _options = [
  ExerciseOption(id: 'true', text: {'en': 'True'}),
  ExerciseOption(id: 'false', text: {'en': 'False'}),
];

const _exercises = [
  Exercise(
    id: 'exercise-choice',
    type: 'multiple_choice',
    prompt: {'en': 'Choose.'},
    options: _options,
  ),
  Exercise(
    id: 'exercise-truth',
    type: 'true_false',
    prompt: {'en': 'True?'},
    options: _options,
  ),
  Exercise(
    id: 'exercise-listen',
    type: 'listen_select',
    prompt: {'en': 'Listen.'},
    transcript: {'en': 'Hello'},
    options: _options,
  ),
  Exercise(
    id: 'exercise-read',
    type: 'comprehension',
    prompt: {'en': 'Read.'},
    options: _options,
  ),
  Exercise(id: 'exercise-card', type: 'flashcard', prompt: {'en': 'Hello'}),
  Exercise(id: 'exercise-fill', type: 'fill_blank', prompt: {'en': 'Fill.'}),
  Exercise(
    id: 'exercise-dictation',
    type: 'dictation',
    prompt: {'en': 'Type.'},
    transcript: {'en': 'Hello'},
  ),
  Exercise(
    id: 'exercise-order',
    type: 'ordering',
    prompt: {'en': 'Order.'},
    items: [
      ExerciseOption(id: 'item-a', text: {'en': 'A'}),
      ExerciseOption(id: 'item-b', text: {'en': 'B'}),
    ],
  ),
  Exercise(
    id: 'exercise-match',
    type: 'matching',
    prompt: {'en': 'Match.'},
    leftItems: [
      ExerciseOption(id: 'left-a', text: {'en': 'A'}),
      ExerciseOption(id: 'left-b', text: {'en': 'B'}),
    ],
    rightItems: [
      ExerciseOption(id: 'right-a', text: {'en': 'One'}),
      ExerciseOption(id: 'right-b', text: {'en': 'Two'}),
    ],
  ),
];

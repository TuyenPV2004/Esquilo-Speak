import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_repository.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_flow_screen.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_view_model.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('downloads and completes all 45 Unit 1 exercises', (
    tester,
  ) async {
    final repository = _UnitOneRepository();
    final viewModel = LearningViewModel(
      repository,
      learningContext: () => const LearningContextSnapshot(
        sourceLanguage: 'vi',
        targetLanguage: null,
        activeCourseId: null,
      ),
      onCourseSelected: (_) async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: LearningFlowScreen(viewModel: viewModel),
      ),
    );

    await viewModel.loadCatalog();
    await tester.pump();
    await _tap(tester, const ValueKey('language-en'));
    await _tap(tester, const ValueKey('course-course-en-for-vi'));
    expect(find.text('First contact'), findsOneWidget);
    await _tap(tester, const ValueKey('download-unit-unit-first-contact'));
    expect(find.text('Available offline'), findsOneWidget);

    for (var lessonIndex = 0; lessonIndex < 5; lessonIndex++) {
      await _tap(tester, ValueKey('lesson-lesson-unit-one-${lessonIndex + 1}'));
      for (var exerciseIndex = 0; exerciseIndex < 9; exerciseIndex++) {
        final exercise = viewModel.selectedLesson!.exercises[exerciseIndex];
        expect(find.byKey(ValueKey('exercise-${exercise.id}')), findsOneWidget);
        viewModel.setResponse(_responseFor(exercise));
        await tester.pump();
        await _tap(tester, const ValueKey('attempt-submit'));
        expect(find.byKey(const ValueKey('feedback')), findsOneWidget);
        await _tap(tester, const ValueKey('progress-view'));
      }
      expect(find.byKey(const ValueKey('progress')), findsOneWidget);
      if (lessonIndex < 4) {
        await _tap(tester, const ValueKey('continue-from-progress'));
      }
    }

    expect(repository.completedExerciseIds, hasLength(45));
    expect(viewModel.courseProgress?.completedExerciseCount, 45);
    expect(
      viewModel.courseProgress?.lessonProgress.where(
        (lesson) => lesson.status == 'completed',
      ),
      hasLength(5),
    );
  });
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

ExerciseResponse _responseFor(Exercise exercise) => switch (exercise.type) {
  'flashcard' => const SelfAssessmentExerciseResponse('know'),
  'multiple_choice' ||
  'listen_select' ||
  'comprehension' => OptionExerciseResponse(exercise.options.first.id),
  'true_false' => const BooleanExerciseResponse(true),
  'matching' => PairExerciseResponse([
    for (var index = 0; index < exercise.leftItems.length; index++)
      ExercisePair(
        leftId: exercise.leftItems[index].id,
        rightId: exercise.rightItems[index].id,
      ),
  ]),
  'ordering' => SequenceExerciseResponse(
    exercise.items.map((item) => item.id).toList(),
  ),
  'fill_blank' || 'dictation' => const TextExerciseResponse('correct'),
  final type => throw StateError('Unsupported Unit 1 type $type'),
};

class _UnitOneRepository implements LearningRepository, UnitDownloadStore {
  final Set<String> completedExerciseIds = {};
  var downloads = 0;
  var attempts = 0;

  late final List<Lesson> unitLessons = [
    for (var index = 1; index <= 5; index++) _lesson(index),
  ];

  @override
  Future<List<LearningLanguage>> languages() async => const [
    LearningLanguage(
      id: 'language-en',
      languageTag: 'en',
      name: {'en': 'English', 'vi': 'Tiếng Anh'},
    ),
  ];

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) async => const [
    Course(
      id: 'course-en-for-vi',
      sourceLanguage: 'vi',
      targetLanguage: 'en',
      locale: 'vi',
      title: {'en': 'English A1', 'vi': 'Tiếng Anh A1'},
      description: {'en': 'Unit 1', 'vi': 'Unit 1'},
    ),
  ];

  @override
  Future<List<LessonSummary>> lessons(String courseId) async => [
    for (var index = 0; index < unitLessons.length; index++)
      LessonSummary(
        id: unitLessons[index].id,
        version: 2,
        locale: 'vi',
        title: unitLessons[index].title,
        estimatedMinutes: index == 4 ? 10 : 7,
        unitId: 'unit-first-contact',
        unitTitle: const {'en': 'First contact', 'vi': 'Lần gặp đầu tiên'},
        position: index + 1,
      ),
  ];

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async =>
      unitLessons.singleWhere((lesson) => lesson.id == lessonId);

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required ExerciseResponse response,
  }) {
    attempts += 1;
    final suffix = attempts.toString().padLeft(12, '0');
    return PendingAttempt(
      clientAttemptId: '11111111-1111-4111-8111-$suffix',
      clientMutationId: '22222222-2222-4222-8222-$suffix',
      idempotencyKey: '33333333-3333-4333-8333-$suffix',
      courseId: lesson.courseId,
      lessonId: lesson.id,
      lessonVersion: lesson.version,
      exerciseId: exercise.id,
      response: response,
      occurredAt: DateTime.utc(2026, 8, 1),
    );
  }

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    completedExerciseIds.add('${attempt.lessonId}/${attempt.exerciseId}');
    return AttemptFeedback(
      correct: true,
      messageCode: 'answer.correct',
      correctOptionId: null,
      explanation: const {'en': 'Correct.', 'vi': 'Chính xác.'},
      progress: await progress(attempt.courseId),
    );
  }

  @override
  Future<CourseProgress> progress(String courseId) async => CourseProgress(
    courseId: courseId,
    completedExerciseCount: completedExerciseIds.length,
    totalExerciseCount: 45,
    lessonProgress: [
      for (final lesson in unitLessons)
        LessonProgress(
          lessonId: lesson.id,
          lessonVersion: lesson.version,
          status:
              completedExerciseIds
                      .where((id) => id.startsWith('${lesson.id}/'))
                      .length ==
                  9
              ? 'completed'
              : 'in_progress',
          completedExerciseCount: completedExerciseIds
              .where((id) => id.startsWith('${lesson.id}/'))
              .length,
          totalExerciseCount: 9,
        ),
    ],
  );

  @override
  Future<UnitDownloadStatus> unitDownloadStatus({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  }) async => UnitDownloadStatus(
    courseId: courseId,
    unitId: unitId,
    downloadedLessonCount: downloads == 0 ? 0 : lessons.length,
    totalLessonCount: lessons.length,
  );

  @override
  Future<UnitDownloadStatus> downloadUnit({
    required String courseId,
    required String unitId,
    required List<LessonSummary> lessons,
  }) async {
    downloads += 1;
    return UnitDownloadStatus(
      courseId: courseId,
      unitId: unitId,
      downloadedLessonCount: lessons.length,
      totalLessonCount: lessons.length,
    );
  }
}

Lesson _lesson(int lessonNumber) => Lesson(
  id: 'lesson-unit-one-$lessonNumber',
  courseId: 'course-en-for-vi',
  version: 2,
  locale: 'vi',
  title: {
    'en': lessonNumber == 5 ? 'Checkpoint' : 'Lesson $lessonNumber',
    'vi': lessonNumber == 5 ? 'Checkpoint' : 'Bài $lessonNumber',
  },
  objectives: const [
    {
      'en': 'Complete the Unit 1 activity.',
      'vi': 'Hoàn thành hoạt động Unit 1.',
    },
  ],
  exercises: [
    _exercise(lessonNumber, 'flashcard'),
    _exercise(lessonNumber, 'multiple_choice'),
    _exercise(lessonNumber, 'listen_select'),
    _exercise(lessonNumber, 'matching'),
    _exercise(lessonNumber, 'ordering'),
    _exercise(lessonNumber, 'fill_blank'),
    _exercise(lessonNumber, 'true_false'),
    _exercise(lessonNumber, 'comprehension'),
    _exercise(lessonNumber, 'dictation'),
  ],
);

Exercise _exercise(int lesson, String type) => Exercise(
  id: 'exercise-$lesson-$type',
  type: type,
  prompt: {'en': 'Unit 1 $type', 'vi': 'Unit 1 $type'},
  transcript: type == 'listen_select' || type == 'dictation'
      ? const {'en': 'Hello', 'vi': 'Hello'}
      : const {},
  options:
      type == 'multiple_choice' ||
          type == 'listen_select' ||
          type == 'comprehension'
      ? const [
          ExerciseOption(id: 'correct', text: {'en': 'Correct', 'vi': 'Đúng'}),
          ExerciseOption(id: 'other', text: {'en': 'Other', 'vi': 'Khác'}),
        ]
      : type == 'true_false'
      ? const [
          ExerciseOption(id: 'true', text: {'en': 'True', 'vi': 'Đúng'}),
          ExerciseOption(id: 'false', text: {'en': 'False', 'vi': 'Sai'}),
        ]
      : const [],
  items: type == 'ordering'
      ? const [
          ExerciseOption(id: 'first', text: {'en': 'Hello', 'vi': 'Hello'}),
          ExerciseOption(id: 'second', text: {'en': 'Ana', 'vi': 'Ana'}),
        ]
      : const [],
  leftItems: type == 'matching'
      ? const [
          ExerciseOption(
            id: 'left-hello',
            text: {'en': 'Hello', 'vi': 'Hello'},
          ),
          ExerciseOption(id: 'left-bye', text: {'en': 'Bye', 'vi': 'Bye'}),
        ]
      : const [],
  rightItems: type == 'matching'
      ? const [
          ExerciseOption(
            id: 'right-hello',
            text: {'en': 'Greeting', 'vi': 'Lời chào'},
          ),
          ExerciseOption(
            id: 'right-bye',
            text: {'en': 'Goodbye', 'vi': 'Tạm biệt'},
          ),
        ]
      : const [],
);

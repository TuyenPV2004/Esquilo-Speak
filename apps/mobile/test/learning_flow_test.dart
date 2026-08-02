import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_repository.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_flow_screen.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_view_model.dart';
import 'package:esquilospeak_mobile/features/practice/data/practice_models.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'placement recommends the highest eligible start and keeps lower choices',
    () {
      final viewModel = _viewModel(FakeLearningRepository());
      viewModel.selectedCourse = const Course(
        id: 'course-en-for-vi',
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        title: {'en': 'English A1'},
        description: {'en': 'A1'},
        placementPolicy: PlacementPolicy(
          startPoints: [
            PlacementStartPoint(
              unitId: 'unit-one',
              lessonId: 'lesson-one',
              minimumScore: 0,
              levelCode: 'PRE_A1',
              title: {'en': 'Unit 1'},
            ),
            PlacementStartPoint(
              unitId: 'unit-two',
              lessonId: 'lesson-two',
              minimumScore: 50,
              levelCode: 'PRE_A1',
              title: {'en': 'Unit 2'},
            ),
            PlacementStartPoint(
              unitId: 'unit-three',
              lessonId: 'lesson-three',
              minimumScore: 75,
              levelCode: 'A1',
              title: {'en': 'Unit 3'},
            ),
          ],
        ),
      );
      expect(
        viewModel.placementStartPointsForScore(80).map((item) => item.lessonId),
        ['lesson-three', 'lesson-two', 'lesson-one'],
      );
    },
  );

  test(
    'practice submits against canonical lesson with mode evidence',
    () async {
      final repository = CapturePracticeLearningRepository();
      final viewModel = _viewModel(repository);
      await viewModel.chooseCourse(FakeLearningRepository.course);

      await viewModel.startPractice(
        configuration: const PracticeConfiguration(
          mode: PracticeMode.practiceTest,
          count: 3,
        ),
      );
      viewModel.setResponse(const OptionExerciseResponse('option-hello'));
      await viewModel.submitAnswer();

      expect(viewModel.sessionKind, LearningSessionKind.practice);
      expect(
        repository.submitted?.lessonId,
        FakeLearningRepository.lessonValue.id,
      );
      expect(repository.submitted?.lessonId, isNot(startsWith('practice-')));
      expect(repository.submitted?.evidence.practiceMode, 'practice_test');
      expect(viewModel.sessionCorrectCount, 1);
    },
  );

  testWidgets('completes the first learning vertical slice', (tester) async {
    final viewModel = _viewModel(FakeLearningRepository());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
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
    expect(find.text('Tiếng Anh'), findsOneWidget);

    await tester.tap(find.text('Tiếng Anh'));
    await tester.pump();
    expect(find.text('Tiếng Anh căn bản'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu khóa học'));
    await tester.pump();
    expect(find.text('Lời chào cơ bản'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu bài học'));
    await tester.pump();
    expect(find.text('Từ nào có nghĩa là xin chào?'), findsOneWidget);

    await tester.tap(find.text('Hello'));
    await tester.tap(find.text('Kiểm tra đáp án'));
    await tester.pump();
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(find.text('Hello là lời chào thông dụng.'), findsOneWidget);

    await tester.tap(find.text('Xem tiến độ'));
    await tester.pump();
    expect(find.text('Đã hoàn thành 1/1 bài tập'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-from-progress')));
    await tester.pump();
    expect(find.text('Lời chào cơ bản'), findsOneWidget);
  });

  testWidgets('announces selection validation before submitting', (
    tester,
  ) async {
    final viewModel = _viewModel(FakeLearningRepository());
    await viewModel.loadCatalog();
    await viewModel.chooseLanguage(viewModel.languages.last);
    await viewModel.chooseCourse(viewModel.courses.first);
    await viewModel.chooseLesson(viewModel.lessons.first);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
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
    await tester.tap(find.text('Kiểm tra đáp án'));
    await tester.pump();
    expect(
      find.text('Hãy chọn một đáp án trước khi tiếp tục.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps rapid loading transitions uniquely keyed', (tester) async {
    final viewModel = TestLearningViewModel(FakeLearningRepository());
    await tester.pumpWidget(
      MaterialApp(
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

    viewModel.showLoading(LearningStep.catalog);
    await tester.pump();
    viewModel.showContent();
    await tester.pump();
    viewModel.showLoading(LearningStep.courses);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  test(
    'retries an attempt with the same logical mutation identifiers',
    () async {
      final repository = RetryOnceLearningRepository();
      final viewModel = _viewModel(repository);
      await viewModel.loadCatalog();
      await viewModel.chooseLanguage(viewModel.languages.last);
      await viewModel.chooseCourse(viewModel.courses.first);
      await viewModel.chooseLesson(viewModel.lessons.first);
      viewModel.selectOption('option-hello');

      await viewModel.submitAnswer();
      expect(viewModel.error, isNotNull);

      await viewModel.retry();
      expect(viewModel.error, isNull);
      expect(repository.submissions, hasLength(2));
      expect(
        repository.submissions[1].clientAttemptId,
        repository.submissions[0].clientAttemptId,
      );
      expect(
        repository.submissions[1].idempotencyKey,
        repository.submissions[0].idempotencyKey,
      );
    },
  );

  test('reviews mistakes before the lesson summary', () async {
    final repository = MistakeReviewLearningRepository();
    final viewModel = _viewModel(repository);
    await viewModel.loadCatalog();
    await viewModel.chooseLanguage(viewModel.languages.last);
    await viewModel.chooseCourse(viewModel.courses.first);
    await viewModel.chooseLesson(viewModel.lessons.first);

    viewModel.selectOption('option-hello');
    await viewModel.submitAnswer();
    expect(viewModel.feedback?.correct, false);
    await viewModel.continueAfterFeedback();
    expect(viewModel.currentExerciseIndex, 1);

    viewModel.setResponse(const TextExerciseResponse('Hello'));
    await viewModel.submitAnswer();
    await viewModel.continueAfterFeedback();
    expect(viewModel.reviewingMistakes, true);
    expect(viewModel.currentExerciseIndex, 0);

    viewModel.selectOption('option-hello');
    await viewModel.submitAnswer();
    await viewModel.continueAfterFeedback();
    expect(viewModel.step, LearningStep.progress);
    expect(repository.submissions, 3);
  });

  testWidgets('shows the unit path and durable download state', (tester) async {
    final repository = DownloadLearningRepository();
    final viewModel = _viewModel(repository);
    await viewModel.loadCatalog();
    await viewModel.chooseLanguage(viewModel.languages.last);
    await viewModel.chooseCourse(viewModel.courses.first);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
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

    expect(find.text('First contact'), findsOneWidget);
    expect(find.text('0 of 1 lessons completed'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('download-unit-unit-first-contact')),
    );
    await tester.pump();
    expect(find.text('Available offline'), findsOneWidget);
    expect(repository.downloads, 1);
  });
}

LearningViewModel _viewModel(LearningRepository repository) =>
    LearningViewModel(
      repository,
      learningContext: () => const LearningContextSnapshot(
        sourceLanguage: 'vi',
        targetLanguage: null,
        activeCourseId: null,
      ),
      onCourseSelected: (_) async {},
    );

class FakeLearningRepository implements LearningRepository {
  static const languageVi = LearningLanguage(
    id: 'language-vietnamese',
    languageTag: 'vi',
    name: {'vi': 'Tiếng Việt', 'en': 'Vietnamese'},
  );
  static const languageEn = LearningLanguage(
    id: 'language-english',
    languageTag: 'en',
    name: {'vi': 'Tiếng Anh', 'en': 'English'},
  );
  static const course = Course(
    id: 'course-en-for-vi',
    sourceLanguage: 'vi',
    targetLanguage: 'en',
    title: {'vi': 'Tiếng Anh căn bản', 'en': 'Essential English'},
    description: {'vi': 'Học giao tiếp căn bản.', 'en': 'Learn the basics.'},
  );
  static const summary = LessonSummary(
    id: 'lesson-basic-greetings',
    version: 1,
    title: {'vi': 'Lời chào cơ bản', 'en': 'Basic greetings'},
    estimatedMinutes: 5,
  );
  static const exercise = Exercise(
    id: 'exercise-choose-hello',
    type: 'multiple_choice',
    prompt: {
      'vi': 'Từ nào có nghĩa là xin chào?',
      'en': 'Which word is a greeting?',
    },
    options: [
      ExerciseOption(id: 'option-hello', text: {'vi': 'Hello', 'en': 'Hello'}),
      ExerciseOption(
        id: 'option-goodbye',
        text: {'vi': 'Goodbye', 'en': 'Goodbye'},
      ),
    ],
  );
  static const lessonValue = Lesson(
    id: 'lesson-basic-greetings',
    courseId: 'course-en-for-vi',
    version: 1,
    title: {'vi': 'Lời chào cơ bản', 'en': 'Basic greetings'},
    objectives: [
      {'vi': 'Nhận biết lời chào.', 'en': 'Recognize greetings.'},
    ],
    exercises: [exercise],
  );
  static const progressValue = CourseProgress(
    courseId: 'course-en-for-vi',
    completedExerciseCount: 1,
    totalExerciseCount: 1,
  );

  @override
  Future<List<LearningLanguage>> languages() async => [languageVi, languageEn];

  @override
  Future<List<Course>> courses({
    required String sourceLanguage,
    required String targetLanguage,
  }) async => [course];

  @override
  Future<List<LessonSummary>> lessons(String courseId) async => [summary];

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async => lessonValue;

  @override
  PendingAttempt createAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required ExerciseResponse response,
  }) => PendingAttempt(
    clientAttemptId: '11111111-1111-4111-8111-111111111111',
    clientMutationId: '33333333-3333-4333-8333-333333333333',
    idempotencyKey: '22222222-2222-4222-8222-222222222222',
    courseId: lesson.courseId,
    lessonId: lesson.id,
    lessonVersion: lesson.version,
    exerciseId: exercise.id,
    response: response,
    occurredAt: DateTime.utc(2026, 7, 30),
  );

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async =>
      const AttemptFeedback(
        correct: true,
        messageCode: 'answer.correct',
        correctOptionId: 'option-hello',
        explanation: {
          'vi': 'Hello là lời chào thông dụng.',
          'en': 'Hello is a common greeting.',
        },
        progress: progressValue,
      );

  @override
  Future<CourseProgress> progress(String courseId) async => progressValue;
}

class RetryOnceLearningRepository extends FakeLearningRepository {
  final List<PendingAttempt> submissions = [];

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    submissions.add(attempt);
    if (submissions.length == 1) {
      throw const LearningTestException();
    }
    return super.submitAttempt(attempt);
  }
}

class CapturePracticeLearningRepository extends FakeLearningRepository {
  PendingAttempt? submitted;

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    submitted = attempt;
    return super.submitAttempt(attempt);
  }
}

class DownloadLearningRepository extends FakeLearningRepository
    implements UnitDownloadStore {
  int downloads = 0;

  static const unitSummary = LessonSummary(
    id: 'lesson-basic-greetings',
    version: 1,
    title: {'vi': 'Lời chào cơ bản', 'en': 'Basic greetings'},
    estimatedMinutes: 5,
    locale: 'vi',
    unitId: 'unit-first-contact',
    unitTitle: {'vi': 'Lần gặp đầu tiên', 'en': 'First contact'},
    position: 1,
  );

  @override
  Future<List<LessonSummary>> lessons(String courseId) async => [unitSummary];

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

class MistakeReviewLearningRepository extends FakeLearningRepository {
  int submissions = 0;

  static const lessonWithTwoExercises = Lesson(
    id: 'lesson-basic-greetings',
    courseId: 'course-en-for-vi',
    version: 1,
    title: {'vi': 'Lời chào cơ bản', 'en': 'Basic greetings'},
    objectives: [
      {'vi': 'Nhận biết lời chào.', 'en': 'Recognize greetings.'},
    ],
    exercises: [
      FakeLearningRepository.exercise,
      Exercise(
        id: 'exercise-type-hello',
        type: 'fill_blank',
        prompt: {'vi': 'Gõ Hello', 'en': 'Type Hello'},
      ),
    ],
  );

  @override
  Future<Lesson> lesson(String lessonId, {int? version}) async =>
      lessonWithTwoExercises;

  @override
  Future<AttemptFeedback> submitAttempt(PendingAttempt attempt) async {
    submissions += 1;
    return AttemptFeedback(
      correct: submissions != 1,
      messageCode: submissions == 1 ? 'answer.incorrect' : 'answer.correct',
      correctOptionId: 'option-hello',
      explanation: const {'vi': 'Giải thích.', 'en': 'Explanation.'},
      progress: const CourseProgress(
        courseId: 'course-en-for-vi',
        completedExerciseCount: 2,
        totalExerciseCount: 2,
      ),
    );
  }
}

class TestLearningViewModel extends LearningViewModel {
  TestLearningViewModel(super.repository)
    : super(
        learningContext: () => const LearningContextSnapshot(
          sourceLanguage: 'vi',
          targetLanguage: null,
          activeCourseId: null,
        ),
        onCourseSelected: (_) async {},
      );

  void showLoading(LearningStep nextStep) {
    step = nextStep;
    loading = true;
    notifyListeners();
  }

  void showContent() {
    loading = false;
    notifyListeners();
  }
}

class LearningTestException implements Exception {
  const LearningTestException();

  @override
  String toString() =>
      'Response was lost after the server accepted the attempt.';
}

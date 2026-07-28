import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_repository.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_flow_screen.dart';
import 'package:esquilospeak_mobile/features/learning/presentation/learning_view_model.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completes the first learning vertical slice', (tester) async {
    final viewModel = LearningViewModel(FakeLearningRepository());
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
  });

  testWidgets('announces selection validation before submitting', (
    tester,
  ) async {
    final viewModel = LearningViewModel(FakeLearningRepository());
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
}

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
  Future<AttemptFeedback> submitAttempt({
    required Lesson lesson,
    required Exercise exercise,
    required String selectedOptionId,
  }) async => const AttemptFeedback(
    correct: true,
    message: {'vi': 'Chính xác!', 'en': 'Correct!'},
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

import 'package:esquilospeak_mobile/features/advanced_learning/data/p1_models.dart';
import 'package:esquilospeak_mobile/features/home/data/daily_session_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/review/data/learning_insights_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = DailySessionComposer();

  test('prioritizes due reviews and caps the visible backlog by policy', () {
    final reviews = List.generate(
      7,
      (index) => ReviewItem(
        conceptId: 'concept-$index',
        defaultLocale: 'en',
        title: {'en': 'Concept $index'},
        dueAt: DateTime.utc(2026, 8, 2),
        intervalDays: 1,
        repetitions: 1,
        lastResult: 'incorrect',
      ),
    );

    final plan = composer.compose(
      lessons: _lessons,
      progress: _progress(),
      insights: _insights(reviews: reviews),
      unitDownloads: const {},
      policy: _policy,
    );

    expect(plan.kind, DailySessionKind.quickPractice);
    expect(plan.source, DailySessionSource.dueReview);
    expect(plan.visibleReviewCount, 5);
    expect(plan.totalReviewCount, 7);
    expect(plan.conceptIds, hasLength(5));
  });

  test('uses the weakest concept before suggesting a new lesson', () {
    final plan = composer.compose(
      lessons: _lessons,
      progress: _progress(),
      insights: _insights(
        mastery: [_mastery('strong', 0.8), _mastery('weak', 0.2)],
      ),
      unitDownloads: const {
        'unit-1': UnitDownloadStatus(
          courseId: 'course-1',
          unitId: 'unit-1',
          downloadedLessonCount: 2,
          totalLessonCount: 2,
        ),
      },
      policy: _policy,
    );

    expect(plan.source, DailySessionSource.weakConcept);
    expect(plan.conceptIds, ['weak']);
    expect(plan.estimatedMinutes, inInclusiveRange(3, 5));
    expect(plan.offlineReady, isTrue);
  });

  test(
    'selects the first incomplete lesson and reports downloaded readiness',
    () {
      final plan = composer.compose(
        lessons: _lessons,
        progress: _progress(completedLessonIds: const ['lesson-1']),
        insights: _insights(),
        unitDownloads: const {
          'unit-1': UnitDownloadStatus(
            courseId: 'course-1',
            unitId: 'unit-1',
            downloadedLessonCount: 2,
            totalLessonCount: 2,
          ),
        },
        policy: _policy,
      );

      expect(plan.kind, DailySessionKind.lesson);
      expect(plan.source, DailySessionSource.nextLesson);
      expect(plan.lesson?.id, 'lesson-2');
      expect(plan.offlineReady, isTrue);
    },
  );

  test('keeps a quick session available after every lesson is complete', () {
    final plan = composer.compose(
      lessons: _lessons,
      progress: _progress(completedLessonIds: const ['lesson-1', 'lesson-2']),
      insights: _insights(mastery: [_mastery('known', 1)]),
      unitDownloads: const {},
      policy: _policy,
    );

    expect(plan.kind, DailySessionKind.quickPractice);
    expect(plan.source, DailySessionSource.completedCourse);
    expect(plan.lesson, isNull);
  });
}

const _policy = DailyLearningPolicy(
  version: 1,
  reviewBacklogLimit: 5,
  quickPracticeExerciseCount: 3,
  defaultGoalType: 'minutes',
  defaultGoalTarget: 10,
  minutesGoalMin: 5,
  minutesGoalMax: 60,
  lessonsGoalMin: 1,
  lessonsGoalMax: 5,
  reviewsGoalMin: 3,
  reviewsGoalMax: 30,
  quietHoursStart: '21:00:00',
  quietHoursEnd: '07:00:00',
);

const _lessons = [
  LessonSummary(
    id: 'lesson-2',
    version: 1,
    title: {'en': 'Second lesson'},
    estimatedMinutes: 8,
    unitId: 'unit-1',
    position: 2,
  ),
  LessonSummary(
    id: 'lesson-1',
    version: 1,
    title: {'en': 'First lesson'},
    estimatedMinutes: 5,
    unitId: 'unit-1',
    position: 1,
  ),
];

CourseProgress _progress({List<String> completedLessonIds = const []}) =>
    CourseProgress(
      courseId: 'course-1',
      completedExerciseCount: completedLessonIds.length,
      totalExerciseCount: 2,
      lessonProgress: completedLessonIds
          .map(
            (id) => LessonProgress(
              lessonId: id,
              lessonVersion: 1,
              status: 'completed',
              completedExerciseCount: 1,
              totalExerciseCount: 1,
            ),
          )
          .toList(),
    );

LearningInsights _insights({
  List<ReviewItem> reviews = const [],
  List<MasteryState> mastery = const [],
}) => LearningInsights(
  mastery: mastery,
  reviews: reviews,
  recommendation: const LearningRecommendation(
    algorithmVersion: 1,
    kind: LearningRecommendationKind.continueLearning,
  ),
  pendingMutationCount: 0,
  fromCache: false,
);

MasteryState _mastery(String conceptId, double score) => MasteryState(
  conceptId: conceptId,
  defaultLocale: 'en',
  title: {'en': conceptId},
  modelVersion: 1,
  score: score,
  correctEvidenceCount: score == 1 ? 1 : 0,
  evidenceCount: 1,
  lastEvidenceAt: DateTime.utc(2026, 8, 2),
);

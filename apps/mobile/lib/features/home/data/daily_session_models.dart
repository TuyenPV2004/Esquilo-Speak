import '../../advanced_learning/data/p1_models.dart';
import '../../learning/data/learning_models.dart';
import '../../review/data/learning_insights_models.dart';

enum DailySessionKind { lesson, quickPractice }

enum DailySessionSource {
  dueReview,
  weakConcept,
  nextLesson,
  completedCourse,
  startLearning,
}

class DailySessionPlan {
  const DailySessionPlan({
    required this.kind,
    required this.source,
    required this.estimatedMinutes,
    required this.visibleReviewCount,
    required this.totalReviewCount,
    required this.offlineReady,
    this.lesson,
    this.conceptIds = const [],
  });

  final DailySessionKind kind;
  final DailySessionSource source;
  final int estimatedMinutes;
  final int visibleReviewCount;
  final int totalReviewCount;
  final bool offlineReady;
  final LessonSummary? lesson;
  final List<String> conceptIds;
}

class DailySessionComposer {
  const DailySessionComposer();

  DailySessionPlan compose({
    required List<LessonSummary> lessons,
    required CourseProgress? progress,
    required LearningInsights insights,
    required Map<String, UnitDownloadStatus> unitDownloads,
    required DailyLearningPolicy policy,
  }) {
    final completedLessons =
        progress?.lessonProgress
            .where((item) => item.status == 'completed')
            .map((item) => item.lessonId)
            .toSet() ??
        const <String>{};
    final orderedLessons = [...lessons]
      ..sort(
        (left, right) => (left.position ?? 0).compareTo(right.position ?? 0),
      );
    final nextLesson = orderedLessons
        .where((lesson) => !completedLessons.contains(lesson.id))
        .firstOrNull;
    final offlineReady = unitDownloads.values.any(
      (status) => status.downloaded,
    );
    final visibleReviews = insights.reviews
        .take(policy.reviewBacklogLimit)
        .toList(growable: false);

    if (visibleReviews.isNotEmpty) {
      return DailySessionPlan(
        kind: DailySessionKind.quickPractice,
        source: DailySessionSource.dueReview,
        estimatedMinutes: 3,
        visibleReviewCount: visibleReviews.length,
        totalReviewCount: insights.reviews.length,
        offlineReady: offlineReady,
        conceptIds: visibleReviews.map((item) => item.conceptId).toList(),
      );
    }

    final weak = insights.mastery
        .where((item) => item.score < 1)
        .fold<MasteryState?>(
          null,
          (current, item) =>
              current == null || item.score < current.score ? item : current,
        );
    if (weak != null) {
      return DailySessionPlan(
        kind: DailySessionKind.quickPractice,
        source: DailySessionSource.weakConcept,
        estimatedMinutes: 3,
        visibleReviewCount: 0,
        totalReviewCount: 0,
        offlineReady: offlineReady,
        conceptIds: [weak.conceptId],
      );
    }

    if (nextLesson != null) {
      return DailySessionPlan(
        kind: DailySessionKind.lesson,
        source: DailySessionSource.nextLesson,
        estimatedMinutes: nextLesson.estimatedMinutes,
        visibleReviewCount: 0,
        totalReviewCount: 0,
        offlineReady:
            nextLesson.unitId != null &&
            (unitDownloads[nextLesson.unitId]?.downloaded ?? false),
        lesson: nextLesson,
      );
    }

    if (orderedLessons.isNotEmpty) {
      return DailySessionPlan(
        kind: DailySessionKind.quickPractice,
        source: DailySessionSource.completedCourse,
        estimatedMinutes: 3,
        visibleReviewCount: 0,
        totalReviewCount: 0,
        offlineReady: offlineReady,
        conceptIds: insights.mastery.map((item) => item.conceptId).toList(),
      );
    }

    return const DailySessionPlan(
      kind: DailySessionKind.lesson,
      source: DailySessionSource.startLearning,
      estimatedMinutes: 5,
      visibleReviewCount: 0,
      totalReviewCount: 0,
      offlineReady: false,
    );
  }
}

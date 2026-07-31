import '../../../core/localization/localized_text.dart';

class MasteryState {
  const MasteryState({
    required this.conceptId,
    required this.defaultLocale,
    required this.title,
    required this.modelVersion,
    required this.score,
    required this.correctEvidenceCount,
    required this.evidenceCount,
    required this.lastEvidenceAt,
    this.calculationMethod,
  });

  factory MasteryState.fromJson(Map<String, dynamic> json) {
    final explanation = json['explanation'] as Map<String, dynamic>;
    return MasteryState(
      conceptId: json['conceptId'] as String,
      defaultLocale: json['defaultLocale'] as String? ?? 'und',
      title: json['title'] == null
          ? {'und': json['conceptId'] as String}
          : localizedText(json['title']),
      modelVersion: json['modelVersion'] as int,
      score: (json['score'] as num).toDouble(),
      correctEvidenceCount: json['correctEvidenceCount'] as int,
      evidenceCount: json['evidenceCount'] as int,
      lastEvidenceAt: DateTime.parse(json['lastEvidenceAt'] as String).toUtc(),
      calculationMethod: explanation['method'] as String?,
    );
  }

  final String conceptId;
  final String defaultLocale;
  final LocalizedText title;
  final int modelVersion;
  final double score;
  final int correctEvidenceCount;
  final int evidenceCount;
  final DateTime lastEvidenceAt;
  final String? calculationMethod;
}

class ReviewItem {
  const ReviewItem({
    required this.conceptId,
    required this.defaultLocale,
    required this.title,
    required this.dueAt,
    required this.intervalDays,
    required this.repetitions,
    required this.lastResult,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
    conceptId: json['conceptId'] as String,
    defaultLocale: json['defaultLocale'] as String? ?? 'und',
    title: json['title'] == null
        ? {'und': json['conceptId'] as String}
        : localizedText(json['title']),
    dueAt: DateTime.parse(json['dueAt'] as String).toUtc(),
    intervalDays: json['intervalDays'] as int,
    repetitions: json['repetitions'] as int,
    lastResult: json['lastResult'] as String,
  );

  final String conceptId;
  final String defaultLocale;
  final LocalizedText title;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final String lastResult;
}

enum LearningRecommendationKind {
  reviewDue,
  strengthenWeakConcept,
  continueLearning,
  startLearning,
}

class LearningRecommendation {
  const LearningRecommendation({
    required this.algorithmVersion,
    required this.kind,
    this.conceptId,
    this.defaultLocale,
    this.conceptTitle,
    this.masteryScore,
  });

  final int algorithmVersion;
  final LearningRecommendationKind kind;
  final String? conceptId;
  final String? defaultLocale;
  final LocalizedText? conceptTitle;
  final double? masteryScore;
}

class LearningInsights {
  const LearningInsights({
    required this.mastery,
    required this.reviews,
    required this.recommendation,
    required this.pendingMutationCount,
    required this.fromCache,
  });

  final List<MasteryState> mastery;
  final List<ReviewItem> reviews;
  final LearningRecommendation recommendation;
  final int pendingMutationCount;
  final bool fromCache;
}

class MasteryState {
  const MasteryState({
    required this.conceptId,
    required this.modelVersion,
    required this.score,
    required this.correctEvidenceCount,
    required this.evidenceCount,
  });

  factory MasteryState.fromJson(Map<String, dynamic> json) => MasteryState(
    conceptId: json['conceptId'] as String,
    modelVersion: json['modelVersion'] as int,
    score: (json['score'] as num).toDouble(),
    correctEvidenceCount: json['correctEvidenceCount'] as int,
    evidenceCount: json['evidenceCount'] as int,
  );

  final String conceptId;
  final int modelVersion;
  final double score;
  final int correctEvidenceCount;
  final int evidenceCount;
}

class ReviewItem {
  const ReviewItem({
    required this.conceptId,
    required this.dueAt,
    required this.intervalDays,
    required this.repetitions,
    required this.lastResult,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
    conceptId: json['conceptId'] as String,
    dueAt: DateTime.parse(json['dueAt'] as String).toUtc(),
    intervalDays: json['intervalDays'] as int,
    repetitions: json['repetitions'] as int,
    lastResult: json['lastResult'] as String,
  );

  final String conceptId;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final String lastResult;
}

class LearningInsights {
  const LearningInsights({
    required this.mastery,
    required this.reviews,
    required this.pendingMutationCount,
    required this.fromCache,
  });

  final List<MasteryState> mastery;
  final List<ReviewItem> reviews;
  final int pendingMutationCount;
  final bool fromCache;
}

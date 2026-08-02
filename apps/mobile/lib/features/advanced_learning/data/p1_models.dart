import 'package:flutter/foundation.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/models/proficiency_models.dart';

@immutable
class AdvancedActivityDefinition {
  const AdvancedActivityDefinition({
    required this.id,
    required this.contentRef,
    required this.mediaId,
    required this.expectedText,
    required this.targetLocale,
    required this.feedbackLocale,
  });

  factory AdvancedActivityDefinition.fromJson(Map<String, dynamic> json) =>
      AdvancedActivityDefinition(
        id: json['id'] as String,
        contentRef: json['contentRef'] as String,
        mediaId: json['mediaId'] as String,
        expectedText: json['expectedText'] as String,
        targetLocale: json['targetLocale'] as String,
        feedbackLocale: json['feedbackLocale'] as String,
      );

  final String id;
  final String contentRef;
  final String mediaId;
  final String expectedText;
  final String targetLocale;
  final String feedbackLocale;
}

@immutable
class AdvancedFeedback {
  const AdvancedFeedback({
    required this.id,
    required this.kind,
    required this.feedback,
    required this.provider,
    required this.createdAt,
    this.transcript,
    this.score,
  });

  factory AdvancedFeedback.fromJson(Map<String, dynamic> json) =>
      AdvancedFeedback(
        id: json['id'] as String,
        kind: json['kind'] as String,
        transcript: json['transcript'] as String?,
        score: (json['score'] as num?)?.toDouble(),
        feedback: Map<String, dynamic>.from(
          json['feedback'] as Map? ?? const <String, dynamic>{},
        ),
        provider: json['provider'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String kind;
  final String? transcript;
  final double? score;
  final Map<String, dynamic> feedback;
  final String provider;
  final DateTime createdAt;
}

@immutable
class PlacementQuestion {
  const PlacementQuestion({
    required this.id,
    required this.prompt,
    required this.options,
  });

  factory PlacementQuestion.fromJson(
    Map<String, dynamic> json,
  ) => PlacementQuestion(
    id: json['id'] as String,
    prompt: localizedText(json['prompt']),
    options: (json['options'] as List)
        .map(
          (item) =>
              PlacementOption.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );

  final String id;
  final LocalizedText prompt;
  final List<PlacementOption> options;
}

@immutable
class PlacementOption {
  const PlacementOption({required this.id, required this.text});

  factory PlacementOption.fromJson(Map<String, dynamic> json) =>
      PlacementOption(
        id: json['id'] as String,
        text: localizedText(json['text']),
      );

  final String id;
  final LocalizedText text;
}

@immutable
class PlacementAssessment {
  const PlacementAssessment({
    required this.id,
    required this.courseId,
    required this.defaultLocale,
    required this.proficiency,
    required this.passScore,
    required this.questions,
  });

  factory PlacementAssessment.fromJson(Map<String, dynamic> json) =>
      PlacementAssessment(
        id: json['id'] as String,
        courseId: json['courseId'] as String,
        defaultLocale: json['defaultLocale'] as String,
        proficiency: ProficiencyReference.fromJson(
          Map<String, dynamic>.from(json['proficiency'] as Map),
        ),
        passScore: json['passScore'] as int,
        questions: (json['questions'] as List)
            .map(
              (item) => PlacementQuestion.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );

  final String id;
  final String courseId;
  final String defaultLocale;
  final ProficiencyReference proficiency;
  final int passScore;
  final List<PlacementQuestion> questions;
}

@immutable
class PlacementResult {
  const PlacementResult({
    required this.score,
    required this.passed,
    required this.proficiency,
    required this.completedAt,
    required this.hasCompletionRecord,
  });

  factory PlacementResult.fromJson(Map<String, dynamic> json) =>
      PlacementResult(
        score: json['score'] as int,
        passed: json['passed'] as bool,
        proficiency: ProficiencyReference.fromJson(
          Map<String, dynamic>.from(json['proficiency'] as Map),
        ),
        completedAt: DateTime.parse(json['completedAt'] as String),
        hasCompletionRecord: json['completionRecord'] != null,
      );

  final int score;
  final bool passed;
  final ProficiencyReference proficiency;
  final DateTime completedAt;
  final bool hasCompletionRecord;
}

@immutable
class Achievement {
  const Achievement({
    required this.code,
    required this.title,
    required this.description,
    required this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    code: json['code'] as String,
    title: localizedText(json['title']),
    description: localizedText(json['description']),
    earnedAt: DateTime.parse(json['earnedAt'] as String),
  );

  final String code;
  final LocalizedText title;
  final LocalizedText description;
  final DateTime earnedAt;
}

@immutable
class EngagementStatus {
  const EngagementStatus({
    required this.currentStreak,
    required this.longestStreak,
    required this.xp,
    required this.achievements,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.timezone,
    required this.dailyLearningPolicy,
    required this.dailyGoal,
    this.lastLearningDate,
  });

  factory EngagementStatus.fromJson(Map<String, dynamic> json) {
    final preference = Map<String, dynamic>.from(
      json['notificationPreference'] as Map? ?? const <String, dynamic>{},
    );
    return EngagementStatus(
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      xp: json['xp'] as int,
      lastLearningDate: json['lastLearningDate'] == null
          ? null
          : DateTime.parse(json['lastLearningDate'] as String),
      achievements: (json['achievements'] as List)
          .map(
            (item) =>
                Achievement.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      reminderEnabled: preference['enabled'] as bool? ?? false,
      reminderTime: preference['reminderTime'] as String?,
      timezone: preference['timezone'] as String? ?? 'UTC',
      dailyLearningPolicy: DailyLearningPolicy.fromJson(
        Map<String, dynamic>.from(json['dailyLearningPolicy'] as Map),
      ),
      dailyGoal: DailyGoalStatus.fromJson(
        Map<String, dynamic>.from(json['dailyGoal'] as Map),
      ),
    );
  }

  final int currentStreak;
  final int longestStreak;
  final int xp;
  final DateTime? lastLearningDate;
  final List<Achievement> achievements;
  final bool reminderEnabled;
  final String? reminderTime;
  final String timezone;
  final DailyLearningPolicy dailyLearningPolicy;
  final DailyGoalStatus dailyGoal;
}

@immutable
class DailyGoalStatus {
  const DailyGoalStatus({
    required this.type,
    required this.target,
    required this.completed,
    required this.achieved,
  });

  factory DailyGoalStatus.fromJson(Map<String, dynamic> json) =>
      DailyGoalStatus(
        type: json['type'] as String,
        target: json['target'] as int,
        completed: json['completed'] as int,
        achieved: json['achieved'] as bool,
      );

  final String type;
  final int target;
  final int completed;
  final bool achieved;
}

@immutable
class DailyLearningPolicy {
  const DailyLearningPolicy({
    required this.version,
    required this.reviewBacklogLimit,
    required this.quickPracticeExerciseCount,
    required this.defaultGoalType,
    required this.defaultGoalTarget,
    required this.minutesGoalMin,
    required this.minutesGoalMax,
    required this.lessonsGoalMin,
    required this.lessonsGoalMax,
    required this.reviewsGoalMin,
    required this.reviewsGoalMax,
    required this.quietHoursStart,
    required this.quietHoursEnd,
  });

  factory DailyLearningPolicy.fromJson(Map<String, dynamic> json) =>
      DailyLearningPolicy(
        version: json['version'] as int,
        reviewBacklogLimit: json['reviewBacklogLimit'] as int,
        quickPracticeExerciseCount: json['quickPracticeExerciseCount'] as int,
        defaultGoalType: json['defaultGoalType'] as String,
        defaultGoalTarget: json['defaultGoalTarget'] as int,
        minutesGoalMin: json['minutesGoalMin'] as int,
        minutesGoalMax: json['minutesGoalMax'] as int,
        lessonsGoalMin: json['lessonsGoalMin'] as int,
        lessonsGoalMax: json['lessonsGoalMax'] as int,
        reviewsGoalMin: json['reviewsGoalMin'] as int,
        reviewsGoalMax: json['reviewsGoalMax'] as int,
        quietHoursStart: json['quietHoursStart'] as String,
        quietHoursEnd: json['quietHoursEnd'] as String,
      );

  final int version;
  final int reviewBacklogLimit;
  final int quickPracticeExerciseCount;
  final String defaultGoalType;
  final int defaultGoalTarget;
  final int minutesGoalMin;
  final int minutesGoalMax;
  final int lessonsGoalMin;
  final int lessonsGoalMax;
  final int reviewsGoalMin;
  final int reviewsGoalMax;
  final String quietHoursStart;
  final String quietHoursEnd;

  bool isQuietTime(int hour, int minute) {
    final value = hour * 60 + minute;
    final start = _minutes(quietHoursStart);
    final end = _minutes(quietHoursEnd);
    if (start == end) return false;
    return start < end
        ? value >= start && value < end
        : value >= start || value < end;
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

@immutable
class Entitlement {
  const Entitlement({
    required this.code,
    required this.status,
    required this.source,
    required this.updatedAt,
    this.validUntil,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
    code: json['code'] as String,
    status: json['status'] as String,
    validUntil: json['validUntil'] == null
        ? null
        : DateTime.parse(json['validUntil'] as String),
    source: json['source'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String code;
  final String status;
  final DateTime? validUntil;
  final String source;
  final DateTime updatedAt;

  bool get active => status == 'active';
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.type,
    required this.locale,
    required this.description,
    required this.status,
    required this.createdAt,
    this.contentRef,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as String,
    type: json['type'] as String,
    contentRef: json['contentRef'] as String?,
    locale: json['locale'] as String,
    description: json['description'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String type;
  final String? contentRef;
  final String locale;
  final String description;
  final String status;
  final DateTime createdAt;
}

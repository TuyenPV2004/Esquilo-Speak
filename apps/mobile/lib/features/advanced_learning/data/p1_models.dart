import 'package:flutter/foundation.dart';

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

  factory PlacementQuestion.fromJson(Map<String, dynamic> json) =>
      PlacementQuestion(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        options: (json['options'] as List).cast<String>(),
      );

  final String id;
  final String prompt;
  final List<String> options;
}

@immutable
class PlacementAssessment {
  const PlacementAssessment({
    required this.id,
    required this.courseId,
    required this.proficiency,
    required this.passScore,
    required this.questions,
  });

  factory PlacementAssessment.fromJson(Map<String, dynamic> json) =>
      PlacementAssessment(
        id: json['id'] as String,
        courseId: json['courseId'] as String,
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
  const Achievement({required this.code, required this.earnedAt});

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    code: json['code'] as String,
    earnedAt: DateTime.parse(json['earnedAt'] as String),
  );

  final String code;
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

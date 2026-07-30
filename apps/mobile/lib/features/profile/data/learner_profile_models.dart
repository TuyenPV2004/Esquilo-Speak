enum LearnerActorType { guest, account }

enum LearnerAgeBand { under16, age16To17, adult }

extension LearnerAgeBandApi on LearnerAgeBand {
  String get apiValue => switch (this) {
    LearnerAgeBand.under16 => 'under_16',
    LearnerAgeBand.age16To17 => '16_17',
    LearnerAgeBand.adult => 'adult',
  };
}

class LearnerPreferences {
  const LearnerPreferences({
    this.dailyGoalMinutes = 10,
    this.notificationsEnabled = false,
  });

  factory LearnerPreferences.fromJson(Map<String, dynamic> json) =>
      LearnerPreferences(
        dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 10,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      );

  final int dailyGoalMinutes;
  final bool notificationsEnabled;

  Map<String, dynamic> toJson() => {
    'dailyGoalMinutes': dailyGoalMinutes,
    'notificationsEnabled': notificationsEnabled,
  };
}

class LearnerProfile {
  const LearnerProfile({
    required this.learnerId,
    required this.actorType,
    required this.uiLocale,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.ageBand,
    required this.learningGoal,
    required this.preferences,
    required this.updatedAt,
  });

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
    learnerId: json['learnerId'] as String,
    actorType: LearnerActorType.values.byName(json['actorType'] as String),
    uiLocale: json['uiLocale'] as String,
    sourceLanguage: json['sourceLanguage'] as String,
    targetLanguage: json['targetLanguage'] as String,
    ageBand: _ageBand(json['ageBand'] as String?),
    learningGoal: json['learningGoal'] as String?,
    preferences: LearnerPreferences.fromJson(
      (json['preferences'] as Map<String, dynamic>?) ?? const {},
    ),
    updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
  );

  final String learnerId;
  final LearnerActorType actorType;
  final String uiLocale;
  final String sourceLanguage;
  final String targetLanguage;
  final LearnerAgeBand? ageBand;
  final String? learningGoal;
  final LearnerPreferences preferences;
  final DateTime updatedAt;

  bool get onboardingComplete => ageBand != null;

  Map<String, dynamic> toJson() => {
    'learnerId': learnerId,
    'actorType': actorType.name,
    'uiLocale': uiLocale,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    if (ageBand != null) 'ageBand': ageBand!.apiValue,
    if (learningGoal != null) 'learningGoal': learningGoal,
    'preferences': preferences.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static LearnerAgeBand? _ageBand(String? value) => switch (value) {
    'under_16' => LearnerAgeBand.under16,
    '16_17' => LearnerAgeBand.age16To17,
    'adult' => LearnerAgeBand.adult,
    _ => null,
  };
}

class ConsentRecord {
  const ConsentRecord({
    required this.purpose,
    required this.policyVersion,
    required this.granted,
    required this.recordedAt,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
    purpose: json['purpose'] as String,
    policyVersion: json['policyVersion'] as String,
    granted: json['granted'] as bool,
    recordedAt: DateTime.parse(json['recordedAt'] as String).toUtc(),
  );

  final String purpose;
  final String policyVersion;
  final bool granted;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'policyVersion': policyVersion,
    'granted': granted,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };
}

class PrivacyRequest {
  const PrivacyRequest({
    required this.requestId,
    required this.requestType,
    required this.state,
    required this.requestedAt,
    required this.targetAt,
  });

  factory PrivacyRequest.fromJson(Map<String, dynamic> json) => PrivacyRequest(
    requestId: json['requestId'] as String,
    requestType: json['requestType'] as String,
    state: json['state'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String).toUtc(),
    targetAt: DateTime.parse(json['targetAt'] as String).toUtc(),
  );

  final String requestId;
  final String requestType;
  final String state;
  final DateTime requestedAt;
  final DateTime targetAt;
}

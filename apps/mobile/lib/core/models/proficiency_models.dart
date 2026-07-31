import 'package:flutter/foundation.dart';

@immutable
class ProficiencyReference {
  const ProficiencyReference({
    required this.frameworkCode,
    required this.frameworkVersion,
    required this.levelCode,
  });

  factory ProficiencyReference.fromJson(Map<String, dynamic> json) =>
      ProficiencyReference(
        frameworkCode: json['frameworkCode'] as String,
        frameworkVersion: json['frameworkVersion'] as String,
        levelCode: json['levelCode'] as String,
      );

  final String frameworkCode;
  final String frameworkVersion;
  final String levelCode;

  Map<String, dynamic> toJson() => {
    'frameworkCode': frameworkCode,
    'frameworkVersion': frameworkVersion,
    'levelCode': levelCode,
  };
}

@immutable
class CourseProficiency {
  const CourseProficiency({
    required this.frameworkCode,
    required this.frameworkVersion,
    required this.entryLevelCode,
    required this.targetLevelCode,
  });

  factory CourseProficiency.fromJson(Map<String, dynamic> json) =>
      CourseProficiency(
        frameworkCode: json['frameworkCode'] as String,
        frameworkVersion: json['frameworkVersion'] as String,
        entryLevelCode: json['entryLevelCode'] as String,
        targetLevelCode: json['targetLevelCode'] as String,
      );

  final String frameworkCode;
  final String frameworkVersion;
  final String entryLevelCode;
  final String targetLevelCode;

  Map<String, dynamic> toJson() => {
    'frameworkCode': frameworkCode,
    'frameworkVersion': frameworkVersion,
    'entryLevelCode': entryLevelCode,
    'targetLevelCode': targetLevelCode,
  };
}

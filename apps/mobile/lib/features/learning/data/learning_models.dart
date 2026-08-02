import '../../../core/models/proficiency_models.dart';
import '../../../core/localization/localized_text.dart';

export '../../../core/localization/localized_text.dart';

String localized(
  LocalizedText values,
  String locale, {
  String? defaultLocale,
}) => resolveLocalizedText(values, locale, defaultLocale: defaultLocale);

class LearningLanguage {
  const LearningLanguage({
    required this.id,
    required this.languageTag,
    required this.name,
  });

  factory LearningLanguage.fromJson(Map<String, dynamic> json) =>
      LearningLanguage(
        id: json['id'] as String,
        languageTag: json['languageTag'] as String,
        name: localizedText(json['name']),
      );

  final String id;
  final String languageTag;
  final LocalizedText name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'languageTag': languageTag,
    'name': name,
  };
}

class Course {
  const Course({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.title,
    required this.description,
    this.locale,
    this.proficiency,
    this.completionAssessment,
    this.placementPolicy,
    this.versionMigrationPolicy,
    this.offlinePackagePolicy,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    sourceLanguage: json['sourceLanguage'] as String,
    targetLanguage: json['targetLanguage'] as String,
    locale: json['locale'] as String?,
    proficiency: json['proficiency'] == null
        ? null
        : CourseProficiency.fromJson(
            Map<String, dynamic>.from(json['proficiency'] as Map),
          ),
    completionAssessment: json['completionAssessment'] == null
        ? null
        : CompletionAssessmentPolicy.fromJson(
            Map<String, dynamic>.from(json['completionAssessment'] as Map),
          ),
    placementPolicy: json['placementPolicy'] == null
        ? null
        : PlacementPolicy.fromJson(
            Map<String, dynamic>.from(json['placementPolicy'] as Map),
          ),
    versionMigrationPolicy: json['versionMigrationPolicy'] == null
        ? null
        : VersionMigrationPolicy.fromJson(
            Map<String, dynamic>.from(json['versionMigrationPolicy'] as Map),
          ),
    offlinePackagePolicy: json['offlinePackagePolicy'] == null
        ? null
        : OfflinePackagePolicy.fromJson(
            Map<String, dynamic>.from(json['offlinePackagePolicy'] as Map),
          ),
    title: localizedText(json['title']),
    description: localizedText(json['description']),
  );

  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final String? locale;
  final CourseProficiency? proficiency;
  final CompletionAssessmentPolicy? completionAssessment;
  final PlacementPolicy? placementPolicy;
  final VersionMigrationPolicy? versionMigrationPolicy;
  final OfflinePackagePolicy? offlinePackagePolicy;
  final LocalizedText title;
  final LocalizedText description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    if (locale != null) 'locale': locale,
    if (proficiency != null) 'proficiency': proficiency!.toJson(),
    if (completionAssessment != null)
      'completionAssessment': completionAssessment!.toJson(),
    if (placementPolicy != null) 'placementPolicy': placementPolicy!.toJson(),
    if (versionMigrationPolicy != null)
      'versionMigrationPolicy': versionMigrationPolicy!.toJson(),
    if (offlinePackagePolicy != null)
      'offlinePackagePolicy': offlinePackagePolicy!.toJson(),
    'title': title,
    'description': description,
  };
}

class CompletionAssessmentPolicy {
  const CompletionAssessmentPolicy({
    required this.checkpointLessonId,
    required this.recordType,
    required this.minimumScore,
    required this.skillCoverage,
  });
  factory CompletionAssessmentPolicy.fromJson(Map<String, dynamic> json) =>
      CompletionAssessmentPolicy(
        checkpointLessonId: json['checkpointLessonId'] as String,
        recordType: json['recordType'] as String,
        minimumScore: json['minimumScore'] as int,
        skillCoverage: (json['skillCoverage'] as List<dynamic>).cast<String>(),
      );
  final String checkpointLessonId;
  final String recordType;
  final int minimumScore;
  final List<String> skillCoverage;
  Map<String, dynamic> toJson() => {
    'checkpointLessonId': checkpointLessonId,
    'recordType': recordType,
    'minimumScore': minimumScore,
    'skillCoverage': skillCoverage,
  };
}

class PlacementStartPoint {
  const PlacementStartPoint({
    required this.unitId,
    required this.lessonId,
    required this.minimumScore,
    required this.levelCode,
    required this.title,
  });
  factory PlacementStartPoint.fromJson(Map<String, dynamic> json) =>
      PlacementStartPoint(
        unitId: json['unitId'] as String,
        lessonId: json['lessonId'] as String,
        minimumScore: json['minimumScore'] as int,
        levelCode: json['levelCode'] as String,
        title: localizedText(json['title']),
      );
  final String unitId;
  final String lessonId;
  final int minimumScore;
  final String levelCode;
  final LocalizedText title;
  Map<String, dynamic> toJson() => {
    'unitId': unitId,
    'lessonId': lessonId,
    'minimumScore': minimumScore,
    'levelCode': levelCode,
    'title': title,
  };
}

class PlacementPolicy {
  const PlacementPolicy({required this.startPoints});
  factory PlacementPolicy.fromJson(Map<String, dynamic> json) =>
      PlacementPolicy(
        startPoints: (json['startPoints'] as List<dynamic>)
            .map(
              (item) => PlacementStartPoint.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
  final List<PlacementStartPoint> startPoints;
  Map<String, dynamic> toJson() => {
    'startPoints': startPoints.map((item) => item.toJson()).toList(),
  };
}

class VersionMigrationPolicy {
  const VersionMigrationPolicy({
    required this.policyVersion,
    required this.compatibleFromCourseVersion,
    required this.onIncompatible,
    required this.preserveMastery,
  });
  factory VersionMigrationPolicy.fromJson(Map<String, dynamic> json) =>
      VersionMigrationPolicy(
        policyVersion: json['policyVersion'] as int,
        compatibleFromCourseVersion: json['compatibleFromCourseVersion'] as int,
        onIncompatible: json['onIncompatible'] as String,
        preserveMastery: json['preserveMastery'] as bool,
      );
  final int policyVersion;
  final int compatibleFromCourseVersion;
  final String onIncompatible;
  final bool preserveMastery;
  Map<String, dynamic> toJson() => {
    'policyVersion': policyVersion,
    'compatibleFromCourseVersion': compatibleFromCourseVersion,
    'onIncompatible': onIncompatible,
    'preserveMastery': preserveMastery,
  };
}

class OfflinePackagePolicy {
  const OfflinePackagePolicy({
    required this.packageVersion,
    required this.maxBytes,
    required this.cacheTtlDays,
    required this.retainPreviousCompatibleVersions,
    required this.includesMedia,
  });
  factory OfflinePackagePolicy.fromJson(Map<String, dynamic> json) =>
      OfflinePackagePolicy(
        packageVersion: json['packageVersion'] as int,
        maxBytes: json['maxBytes'] as int,
        cacheTtlDays: json['cacheTtlDays'] as int,
        retainPreviousCompatibleVersions:
            json['retainPreviousCompatibleVersions'] as int,
        includesMedia: json['includesMedia'] as bool,
      );
  final int packageVersion;
  final int maxBytes;
  final int cacheTtlDays;
  final int retainPreviousCompatibleVersions;
  final bool includesMedia;
  Map<String, dynamic> toJson() => {
    'packageVersion': packageVersion,
    'maxBytes': maxBytes,
    'cacheTtlDays': cacheTtlDays,
    'retainPreviousCompatibleVersions': retainPreviousCompatibleVersions,
    'includesMedia': includesMedia,
  };
}

class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.version,
    required this.title,
    required this.estimatedMinutes,
    this.locale,
    this.unitId,
    this.unitTitle = const {},
    this.position,
    this.unitGuidebook,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    id: json['id'] as String,
    version: json['version'] as int,
    title: localizedText(json['title']),
    estimatedMinutes: json['estimatedMinutes'] as int,
    locale: json['locale'] as String?,
    unitId: json['unitId'] as String?,
    unitTitle: _optionalLocalizedText(json['unitTitle']),
    position: json['position'] as int?,
    unitGuidebook: json['unitGuidebook'] == null
        ? null
        : UnitGuidebook.fromJson(
            Map<String, dynamic>.from(json['unitGuidebook'] as Map),
          ),
  );

  final String id;
  final int version;
  final LocalizedText title;
  final int estimatedMinutes;
  final String? locale;
  final String? unitId;
  final LocalizedText unitTitle;
  final int? position;
  final UnitGuidebook? unitGuidebook;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'title': title,
    'estimatedMinutes': estimatedMinutes,
    if (locale != null) 'locale': locale,
    if (unitId != null) 'unitId': unitId,
    if (unitTitle.isNotEmpty) 'unitTitle': unitTitle,
    if (position != null) 'position': position,
    if (unitGuidebook != null) 'unitGuidebook': unitGuidebook!.toJson(),
  };
}

class UnitGuidebook {
  const UnitGuidebook({
    required this.summary,
    required this.keyPhrases,
    required this.grammarNotes,
    required this.examples,
  });
  factory UnitGuidebook.fromJson(Map<String, dynamic> json) => UnitGuidebook(
    summary: localizedText(json['summary']),
    keyPhrases: _localizedList(json['keyPhrases']),
    grammarNotes: _localizedList(json['grammarNotes']),
    examples: _localizedList(json['examples']),
  );
  final LocalizedText summary;
  final List<LocalizedText> keyPhrases;
  final List<LocalizedText> grammarNotes;
  final List<LocalizedText> examples;
  Map<String, dynamic> toJson() => {
    'summary': summary,
    'keyPhrases': keyPhrases,
    'grammarNotes': grammarNotes,
    'examples': examples,
  };
}

List<LocalizedText> _localizedList(Object? value) =>
    (value as List<dynamic>? ?? const []).map(localizedText).toList();

class UnitDownloadStatus {
  const UnitDownloadStatus({
    required this.courseId,
    required this.unitId,
    required this.downloadedLessonCount,
    required this.totalLessonCount,
    this.updatedAt,
  });

  final String courseId;
  final String unitId;
  final int downloadedLessonCount;
  final int totalLessonCount;
  final DateTime? updatedAt;

  bool get downloaded =>
      totalLessonCount > 0 && downloadedLessonCount == totalLessonCount;
}

class CourseDownloadStatus {
  const CourseDownloadStatus({
    required this.courseId,
    required this.downloadedLessonCount,
    required this.totalLessonCount,
    required this.packageVersion,
    this.updatedAt,
  });
  final String courseId;
  final int downloadedLessonCount;
  final int totalLessonCount;
  final int packageVersion;
  final DateTime? updatedAt;
  bool get downloaded =>
      totalLessonCount > 0 && downloadedLessonCount == totalLessonCount;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.version,
    required this.title,
    required this.objectives,
    required this.exercises,
    this.locale,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    version: json['version'] as int,
    locale: json['locale'] as String?,
    title: localizedText(json['title']),
    objectives: (json['objectives'] as List<dynamic>)
        .map(localizedText)
        .toList(),
    exercises: (json['exercises'] as List<dynamic>)
        .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String courseId;
  final int version;
  final String? locale;
  final LocalizedText title;
  final List<LocalizedText> objectives;
  final List<Exercise> exercises;

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'version': version,
    if (locale != null) 'locale': locale,
    'title': title,
    'objectives': objectives,
    'exercises': exercises.map((item) => item.toJson()).toList(),
  };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    this.conceptIds = const [],
    this.options = const [],
    this.items = const [],
    this.leftItems = const [],
    this.rightItems = const [],
    this.instruction = const {},
    this.hint = const {},
    this.transcript = const {},
    this.mediaId,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    type: json['type'] as String,
    prompt: localizedText(json['prompt']),
    conceptIds: (json['conceptIds'] as List<dynamic>? ?? const [])
        .cast<String>(),
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((item) => ExerciseOption.fromJson(item as Map<String, dynamic>))
        .toList(),
    items: _exerciseItems(json['items']),
    leftItems: _exerciseItems(json['leftItems']),
    rightItems: _exerciseItems(json['rightItems']),
    instruction: _optionalLocalizedText(json['instruction']),
    hint: _optionalLocalizedText(json['hint']),
    transcript: _optionalLocalizedText(json['transcript']),
    mediaId: (json['media'] as Map<String, dynamic>?)?['id'] as String?,
  );

  final String id;
  final String type;
  final LocalizedText prompt;
  final List<String> conceptIds;
  final List<ExerciseOption> options;
  final List<ExerciseOption> items;
  final List<ExerciseOption> leftItems;
  final List<ExerciseOption> rightItems;
  final LocalizedText instruction;
  final LocalizedText hint;
  final LocalizedText transcript;
  final String? mediaId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'prompt': prompt,
    if (conceptIds.isNotEmpty) 'conceptIds': conceptIds,
    'options': options.map((item) => item.toJson()).toList(),
    if (items.isNotEmpty) 'items': items.map((item) => item.toJson()).toList(),
    if (leftItems.isNotEmpty)
      'leftItems': leftItems.map((item) => item.toJson()).toList(),
    if (rightItems.isNotEmpty)
      'rightItems': rightItems.map((item) => item.toJson()).toList(),
    if (instruction.isNotEmpty) 'instruction': instruction,
    if (hint.isNotEmpty) 'hint': hint,
    if (transcript.isNotEmpty) 'transcript': transcript,
    if (mediaId != null) 'media': {'id': mediaId},
  };
}

List<ExerciseOption> _exerciseItems(Object? value) =>
    (value as List<dynamic>? ?? const [])
        .map((item) => ExerciseOption.fromJson(item as Map<String, dynamic>))
        .toList();

LocalizedText _optionalLocalizedText(Object? value) =>
    value == null ? const <String, String>{} : localizedText(value);

sealed class ExerciseResponse {
  const ExerciseResponse();

  factory ExerciseResponse.fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'option' => OptionExerciseResponse(json['optionId'] as String),
        'boolean' => BooleanExerciseResponse(json['value'] as bool),
        'self_assessment' => SelfAssessmentExerciseResponse(
          json['value'] as String,
        ),
        'text' => TextExerciseResponse(json['text'] as String),
        'sequence' => SequenceExerciseResponse(
          (json['itemIds'] as List<dynamic>).cast<String>(),
        ),
        'pairs' => PairExerciseResponse(
          (json['pairs'] as List<dynamic>)
              .map(
                (item) => ExercisePair.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
        ),
        final kind => throw FormatException('Unsupported response kind: $kind'),
      };

  Map<String, dynamic> toJson();
}

class BooleanExerciseResponse extends ExerciseResponse {
  const BooleanExerciseResponse(this.value);
  final bool value;
  @override
  Map<String, dynamic> toJson() => {'kind': 'boolean', 'value': value};
}

class SelfAssessmentExerciseResponse extends ExerciseResponse {
  const SelfAssessmentExerciseResponse(this.value);
  final String value;
  @override
  Map<String, dynamic> toJson() => {'kind': 'self_assessment', 'value': value};
}

class TextExerciseResponse extends ExerciseResponse {
  const TextExerciseResponse(this.text);
  final String text;
  @override
  Map<String, dynamic> toJson() => {'kind': 'text', 'text': text};
}

class SequenceExerciseResponse extends ExerciseResponse {
  const SequenceExerciseResponse(this.itemIds);
  final List<String> itemIds;
  @override
  Map<String, dynamic> toJson() => {'kind': 'sequence', 'itemIds': itemIds};
}

class ExercisePair {
  const ExercisePair({required this.leftId, required this.rightId});
  factory ExercisePair.fromJson(Map<String, dynamic> json) => ExercisePair(
    leftId: json['leftId'] as String,
    rightId: json['rightId'] as String,
  );
  final String leftId;
  final String rightId;
  Map<String, dynamic> toJson() => {'leftId': leftId, 'rightId': rightId};
}

class PairExerciseResponse extends ExerciseResponse {
  const PairExerciseResponse(this.pairs);
  final List<ExercisePair> pairs;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'pairs',
    'pairs': pairs.map((pair) => pair.toJson()).toList(),
  };
}

class AttemptEvidence {
  const AttemptEvidence({
    required this.responseTimeMs,
    this.hintUsed = false,
    this.hintLevel = 0,
    this.retryIndex = 0,
    this.confidence,
    this.inputModality = 'touch',
    this.practiceMode,
  });

  final int responseTimeMs;
  final bool hintUsed;
  final int hintLevel;
  final int retryIndex;
  final int? confidence;
  final String inputModality;
  final String? practiceMode;

  Map<String, dynamic> toJson() => {
    'responseTimeMs': responseTimeMs,
    'hintUsed': hintUsed,
    'hintLevel': hintLevel,
    'retryIndex': retryIndex,
    if (confidence != null) 'confidence': confidence,
    'inputModality': inputModality,
    if (practiceMode != null) 'practiceMode': practiceMode,
  };
}

class OptionExerciseResponse extends ExerciseResponse {
  const OptionExerciseResponse(this.optionId);

  final String optionId;

  @override
  Map<String, dynamic> toJson() => {'kind': 'option', 'optionId': optionId};
}

class ExerciseOption {
  const ExerciseOption({required this.id, required this.text});

  factory ExerciseOption.fromJson(Map<String, dynamic> json) => ExerciseOption(
    id: json['id'] as String,
    text: localizedText(json['text']),
  );

  final String id;
  final LocalizedText text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

class PendingAttempt {
  const PendingAttempt({
    required this.clientAttemptId,
    required this.clientMutationId,
    required this.idempotencyKey,
    required this.courseId,
    required this.lessonId,
    required this.lessonVersion,
    required this.exerciseId,
    required this.response,
    required this.occurredAt,
    this.evidence = const AttemptEvidence(responseTimeMs: 0),
  });

  final String clientAttemptId;
  final String clientMutationId;
  final String idempotencyKey;
  final String courseId;
  final String lessonId;
  final int lessonVersion;
  final String exerciseId;
  final ExerciseResponse response;
  final DateTime occurredAt;
  final AttemptEvidence evidence;

  PendingAttempt withEvidence(AttemptEvidence value) => PendingAttempt(
    clientAttemptId: clientAttemptId,
    clientMutationId: clientMutationId,
    idempotencyKey: idempotencyKey,
    courseId: courseId,
    lessonId: lessonId,
    lessonVersion: lessonVersion,
    exerciseId: exerciseId,
    response: response,
    occurredAt: occurredAt,
    evidence: value,
  );

  Map<String, dynamic> toJson() => {
    'clientAttemptId': clientAttemptId,
    'courseId': courseId,
    'lessonId': lessonId,
    'lessonVersion': lessonVersion,
    'exerciseId': exerciseId,
    'response': response.toJson(),
    'evidence': evidence.toJson(),
    'responseTimeMs': evidence.responseTimeMs,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

class AttemptFeedback {
  const AttemptFeedback({
    required this.correct,
    required this.messageCode,
    required this.correctOptionId,
    this.correctResponse,
    required this.explanation,
    required this.progress,
  });

  factory AttemptFeedback.fromJson(Map<String, dynamic> json) {
    final feedback = json['feedback'] as Map<String, dynamic>;
    return AttemptFeedback(
      correct: json['correct'] as bool,
      messageCode:
          feedback['messageCode'] as String? ??
          ((json['correct'] as bool) ? 'answer.correct' : 'answer.incorrect'),
      correctOptionId: feedback['correctOptionId'] as String?,
      correctResponse: feedback['correctResponse'] == null
          ? null
          : ExerciseResponse.fromJson(
              Map<String, dynamic>.from(feedback['correctResponse'] as Map),
            ),
      explanation: localizedText(feedback['explanation']),
      progress: CourseProgress.fromJson(
        json['progress'] as Map<String, dynamic>,
      ),
    );
  }

  final bool correct;
  final String messageCode;
  final String? correctOptionId;
  final ExerciseResponse? correctResponse;
  final LocalizedText explanation;
  final CourseProgress progress;
}

class CourseProgress {
  const CourseProgress({
    required this.courseId,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    this.lessonProgress = const [],
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) => CourseProgress(
    courseId: json['courseId'] as String,
    completedExerciseCount: json['completedExerciseCount'] as int,
    totalExerciseCount: json['totalExerciseCount'] as int,
    lessonProgress: (json['lessonProgress'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              LessonProgress.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  final String courseId;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final List<LessonProgress> lessonProgress;

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'completedExerciseCount': completedExerciseCount,
    'totalExerciseCount': totalExerciseCount,
    'lessonProgress': lessonProgress.map((item) => item.toJson()).toList(),
  };
}

class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.lessonVersion,
    required this.status,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
    lessonId: json['lessonId'] as String,
    lessonVersion: json['lessonVersion'] as int,
    status: json['status'] as String,
    completedExerciseCount: json['completedExerciseCount'] as int,
    totalExerciseCount: json['totalExerciseCount'] as int,
  );

  final String lessonId;
  final int lessonVersion;
  final String status;
  final int completedExerciseCount;
  final int totalExerciseCount;

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'lessonVersion': lessonVersion,
    'status': status,
    'completedExerciseCount': completedExerciseCount,
    'totalExerciseCount': totalExerciseCount,
  };
}

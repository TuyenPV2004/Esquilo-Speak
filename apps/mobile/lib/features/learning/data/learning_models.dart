import '../../../core/models/proficiency_models.dart';

typedef LocalizedText = Map<String, String>;

String localized(LocalizedText values, String locale) =>
    values[locale] ?? values['en'] ?? values.values.firstOrNull ?? '';

LocalizedText localizedText(Object? value) => (value as Map<String, dynamic>)
    .map((key, item) => MapEntry(key, item as String));

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
    this.proficiency,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    sourceLanguage: json['sourceLanguage'] as String,
    targetLanguage: json['targetLanguage'] as String,
    proficiency: json['proficiency'] == null
        ? null
        : CourseProficiency.fromJson(
            Map<String, dynamic>.from(json['proficiency'] as Map),
          ),
    title: localizedText(json['title']),
    description: localizedText(json['description']),
  );

  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final CourseProficiency? proficiency;
  final LocalizedText title;
  final LocalizedText description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    if (proficiency != null) 'proficiency': proficiency!.toJson(),
    'title': title,
    'description': description,
  };
}

class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.version,
    required this.title,
    required this.estimatedMinutes,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    id: json['id'] as String,
    version: json['version'] as int,
    title: localizedText(json['title']),
    estimatedMinutes: json['estimatedMinutes'] as int,
  );

  final String id;
  final int version;
  final LocalizedText title;
  final int estimatedMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'title': title,
    'estimatedMinutes': estimatedMinutes,
  };
}

class Lesson {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.version,
    required this.title,
    required this.objectives,
    required this.exercises,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    version: json['version'] as int,
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
  final LocalizedText title;
  final List<LocalizedText> objectives;
  final List<Exercise> exercises;

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'version': version,
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
    required this.options,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    type: json['type'] as String,
    prompt: localizedText(json['prompt']),
    options: (json['options'] as List<dynamic>)
        .map((item) => ExerciseOption.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String type;
  final LocalizedText prompt;
  final List<ExerciseOption> options;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'prompt': prompt,
    'options': options.map((item) => item.toJson()).toList(),
  };
}

sealed class ExerciseResponse {
  const ExerciseResponse();

  factory ExerciseResponse.fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'option' => OptionExerciseResponse(json['optionId'] as String),
        final kind => throw FormatException('Unsupported response kind: $kind'),
      };

  Map<String, dynamic> toJson();
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

  Map<String, dynamic> toJson() => {
    'clientAttemptId': clientAttemptId,
    'courseId': courseId,
    'lessonId': lessonId,
    'lessonVersion': lessonVersion,
    'exerciseId': exerciseId,
    'response': response.toJson(),
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

class AttemptFeedback {
  const AttemptFeedback({
    required this.correct,
    required this.message,
    required this.correctOptionId,
    required this.explanation,
    required this.progress,
  });

  factory AttemptFeedback.fromJson(Map<String, dynamic> json) {
    final feedback = json['feedback'] as Map<String, dynamic>;
    return AttemptFeedback(
      correct: json['correct'] as bool,
      message: localizedText(feedback['message']),
      correctOptionId: feedback['correctOptionId'] as String,
      explanation: localizedText(feedback['explanation']),
      progress: CourseProgress.fromJson(
        json['progress'] as Map<String, dynamic>,
      ),
    );
  }

  final bool correct;
  final LocalizedText message;
  final String correctOptionId;
  final LocalizedText explanation;
  final CourseProgress progress;
}

class CourseProgress {
  const CourseProgress({
    required this.courseId,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) => CourseProgress(
    courseId: json['courseId'] as String,
    completedExerciseCount: json['completedExerciseCount'] as int,
    totalExerciseCount: json['totalExerciseCount'] as int,
  );

  final String courseId;
  final int completedExerciseCount;
  final int totalExerciseCount;

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'completedExerciseCount': completedExerciseCount,
    'totalExerciseCount': totalExerciseCount,
  };
}

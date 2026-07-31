import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_api_service.dart';
import 'package:esquilospeak_mobile/features/learning/data/learning_models.dart';
import 'package:esquilospeak_mobile/features/learning/data/remote_learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reuses mutation identifiers during an automatic retry', () async {
    final attemptRequests = <http.Request>[];
    var attemptCount = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/internal/dev/token') {
        return http.Response(
          jsonEncode({'accessToken': 'local-test-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      attemptRequests.add(request);
      attemptCount++;
      if (attemptCount == 1) {
        return http.Response(
          jsonEncode({
            'code': 'TEMPORARY_FAILURE',
            'detail': 'The response was lost.',
          }),
          503,
          headers: {'content-type': 'application/problem+json'},
        );
      }
      return http.Response(
        jsonEncode({
          'correct': true,
          'feedback': {
            'messageCode': 'answer.correct',
            'correctOptionId': 'option-hello',
            'explanation': {
              'vi': 'Hello là lời chào thông dụng.',
              'en': 'Hello is a common greeting.',
            },
          },
          'progress': {
            'courseId': 'course-en-for-vi',
            'completedExerciseCount': 1,
            'totalExerciseCount': 1,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = RemoteLearningRepository(
      LearningApiService(
        ApiClient(
          client,
          Uri.parse('http://localhost:8080'),
          const _TestTokenProvider(),
        ),
      ),
    );
    final attempt = repository.createAttempt(
      lesson: _lesson,
      exercise: _lesson.exercises.first,
      response: const OptionExerciseResponse('option-hello'),
    );

    await repository.submitAttempt(attempt);

    expect(attemptRequests, hasLength(2));
    expect(
      attemptRequests[1].headers['Idempotency-Key'],
      attemptRequests[0].headers['Idempotency-Key'],
    );
    final firstBody =
        jsonDecode(attemptRequests[0].body) as Map<String, dynamic>;
    final secondBody =
        jsonDecode(attemptRequests[1].body) as Map<String, dynamic>;
    expect(secondBody['clientAttemptId'], firstBody['clientAttemptId']);
    expect(secondBody['occurredAt'], firstBody['occurredAt']);
  });
}

class _TestTokenProvider implements AccessTokenProvider {
  const _TestTokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async =>
      'local-test-token';
}

const _lesson = Lesson(
  id: 'lesson-basic-greetings',
  courseId: 'course-en-for-vi',
  version: 1,
  title: {'vi': 'Lời chào cơ bản', 'en': 'Basic greetings'},
  objectives: [
    {'vi': 'Nhận biết lời chào.', 'en': 'Recognize greetings.'},
  ],
  exercises: [
    Exercise(
      id: 'exercise-choose-hello',
      type: 'multiple_choice',
      prompt: {
        'vi': 'Từ nào có nghĩa là xin chào?',
        'en': 'Which word is a greeting?',
      },
      options: [
        ExerciseOption(
          id: 'option-hello',
          text: {'vi': 'Hello', 'en': 'Hello'},
        ),
      ],
    ),
  ],
);

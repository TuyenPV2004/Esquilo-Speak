import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/data/p1_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('maps P1 assessment and feedback contracts', () async {
    final paths = <String>[];
    final queries = <Map<String, String>>[];
    final requestBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      queries.add(request.url.queryParameters);
      if (request.url.path.endsWith('/placement')) {
        return _json({
          'id': 'placement-a1-v1',
          'courseId': 'course-en-for-vi',
          'defaultLocale': 'en',
          'proficiency': {
            'frameworkCode': 'cefr',
            'frameworkVersion': '2020',
            'levelCode': 'A1',
          },
          'passScore': 80,
          'questions': [
            {
              'id': 'q1',
              'prompt': {'en': 'Greeting'},
              'options': [
                {
                  'id': 'hello',
                  'text': {'en': 'Hello'},
                },
                {
                  'id': 'later',
                  'text': {'en': 'Later'},
                },
              ],
            },
          ],
        });
      }
      if (request.url.path.endsWith('/placement/attempts')) {
        requestBodies.add(
          Map<String, dynamic>.from(jsonDecode(request.body) as Map),
        );
        return _json({
          'score': 100,
          'passed': true,
          'proficiency': {
            'frameworkCode': 'cefr',
            'frameworkVersion': '2020',
            'levelCode': 'A1',
          },
          'completedAt': '2026-07-30T00:00:00Z',
          'completionRecord': {'id': 'completion-1'},
        });
      }
      return _json({
        'id': 'feedback-1',
        'kind': 'writing',
        'feedback': {
          'code': 'writing.clearResponse',
          'parameters': {'wordCount': 6},
          'locale': 'en',
        },
        'provider': 'local-deterministic',
        'createdAt': '2026-07-30T00:00:00Z',
      });
    });
    final service = P1ApiService(
      ApiClient(
        client,
        Uri.parse('http://localhost:8080'),
        const _TokenProvider(),
      ),
    );

    final placement = await service.getPlacement('course-en-for-vi');
    final result = await service.submitPlacement(
      assessmentId: placement.id,
      answers: const ['hello'],
    );
    final feedback = await service.textFeedback(
      kind: 'writing',
      contentRef: 'lesson-basic-greetings',
      input: 'Hello, my name is Ana.',
      locale: 'en',
    );

    expect(placement.questions.single.options.first.id, 'hello');
    expect(placement.proficiency.frameworkCode, 'cefr');
    expect(result.proficiency.levelCode, 'A1');
    expect(queries.first, {'courseId': 'course-en-for-vi'});
    expect(requestBodies.single['assessmentId'], 'placement-a1-v1');
    expect(feedback.feedback['code'], 'writing.clearResponse');
    expect(paths, [
      '/api/mobile/v1/assessments/placement',
      '/api/mobile/v1/assessments/placement/attempts',
      '/api/mobile/v1/advanced/writing',
    ]);
  });
}

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

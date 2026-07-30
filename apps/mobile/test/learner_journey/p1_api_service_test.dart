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
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/placement')) {
        return _json({
          'id': 'placement-a1-v1',
          'level': 'A1',
          'passScore': 80,
          'questions': [
            {
              'id': 'q1',
              'prompt': 'Greeting',
              'options': ['hello', 'later'],
            },
          ],
        });
      }
      return _json({
        'id': 'feedback-1',
        'kind': 'writing',
        'feedback': {'summary': 'Clear response.'},
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

    final placement = await service.getPlacement();
    final feedback = await service.textFeedback(
      kind: 'writing',
      contentRef: 'lesson-basic-greetings',
      input: 'Hello, my name is Ana.',
      locale: 'en',
    );

    expect(placement.questions.single.options.first, 'hello');
    expect(feedback.feedback['summary'], 'Clear response.');
    expect(paths, [
      '/api/mobile/v1/assessments/placement',
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

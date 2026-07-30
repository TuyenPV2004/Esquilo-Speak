import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/network/api_problem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('refreshes once after 401 and keeps the correlation ID', () async {
    final correlationIds = <String?>[];
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      correlationIds.add(request.headers['X-Correlation-ID']);
      if (requests == 1) {
        return http.Response(
          jsonEncode({
            'code': 'UNAUTHORIZED',
            'title': 'Unauthorized',
            'status': 401,
            'traceId': 'trace-1',
            'retryable': false,
          }),
          401,
        );
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final tokenProvider = _RecordingTokenProvider();
    final api = ApiClient(
      client,
      Uri.parse('https://api.example.test'),
      tokenProvider,
      maxAttempts: 2,
    );

    final result = await api.get('/profile', authenticated: true);

    expect(result['ok'], isTrue);
    expect(tokenProvider.forceRefreshValues, [false, true]);
    expect(correlationIds.toSet(), hasLength(1));
    expect(correlationIds.first, isNotEmpty);
  });

  test('retries a retryable idempotent mutation', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (requests == 1) {
        return http.Response(
          jsonEncode({
            'code': 'TEMPORARY_FAILURE',
            'title': 'Unavailable',
            'status': 503,
            'traceId': 'trace-2',
            'retryable': true,
          }),
          503,
        );
      }
      return http.Response(jsonEncode({'accepted': true}), 200);
    });
    final api = ApiClient(
      client,
      Uri.parse('https://api.example.test'),
      _RecordingTokenProvider(),
      maxAttempts: 2,
    );

    final result = await api.post(
      '/attempts',
      authenticated: true,
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
      body: const {'answer': 'hello'},
    );

    expect(result['accepted'], isTrue);
    expect(requests, 2);
  });

  test(
    'refreshes a non-idempotent request without retrying server errors',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            jsonEncode({
              'code': 'UNAUTHORIZED',
              'title': 'Unauthorized',
              'status': 401,
              'retryable': false,
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode({
            'code': 'TEMPORARY_FAILURE',
            'title': 'Unavailable',
            'status': 503,
            'retryable': true,
          }),
          503,
        );
      });
      final tokenProvider = _RecordingTokenProvider();
      final api = ApiClient(
        client,
        Uri.parse('https://api.example.test'),
        tokenProvider,
        maxAttempts: 3,
      );

      await expectLater(
        api.post(
          '/privacy/request',
          authenticated: true,
          body: const {'type': 'export'},
        ),
        throwsA(
          isA<ApiProblem>().having((problem) => problem.status, 'status', 503),
        ),
      );

      expect(requests, 2);
      expect(tokenProvider.forceRefreshValues, [false, true]);
    },
  );
}

class _RecordingTokenProvider implements AccessTokenProvider {
  final List<bool> forceRefreshValues = [];

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    forceRefreshValues.add(forceRefresh);
    return forceRefresh ? 'new-token' : 'old-token';
  }
}

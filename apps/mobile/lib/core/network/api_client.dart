import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../auth/auth_session.dart';
import 'api_problem.dart';

class ApiClient {
  ApiClient(
    this._client,
    this._baseUrl,
    this._tokenProvider, {
    this.timeout = const Duration(seconds: 15),
    this.maxAttempts = 3,
    this.uuid = const Uuid(),
  });

  final http.Client _client;
  final Uri _baseUrl;
  final AccessTokenProvider _tokenProvider;
  final Duration timeout;
  final int maxAttempts;
  final Uuid uuid;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
  }) => _request(
    method: 'GET',
    path: path,
    query: query,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = false,
    String? idempotencyKey,
  }) => _request(
    method: 'POST',
    path: path,
    body: body,
    authenticated: authenticated,
    idempotencyKey: idempotencyKey,
  );

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = false,
    String? idempotencyKey,
  }) => _request(
    method: 'PUT',
    path: path,
    body: body,
    authenticated: authenticated,
    idempotencyKey: idempotencyKey,
  );

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    required bool authenticated,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final correlationId = uuid.v4();
    final canRetryMutation =
        (method == 'POST' || method == 'PUT') && idempotencyKey != null;
    final canRetryTransport = method == 'GET' || canRetryMutation;
    final attempts = canRetryTransport ? maxAttempts : (authenticated ? 2 : 1);
    var hasRefreshedAfterUnauthorized = false;
    var forceRefreshNext = false;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final headers = <String, String>{
          'Accept': 'application/json, application/problem+json',
          'Content-Type': 'application/json',
          'X-Correlation-ID': correlationId,
        };
        if (idempotencyKey != null) {
          headers['Idempotency-Key'] = idempotencyKey;
        }
        if (authenticated) {
          final token = await _tokenProvider.accessToken(
            forceRefresh: forceRefreshNext,
          );
          forceRefreshNext = false;
          if (token == null) {
            throw const ApiProblem(
              status: 401,
              code: 'AUTHENTICATION_REQUIRED',
              message: 'A learner session is required.',
              retryable: false,
            );
          }
          headers['Authorization'] = 'Bearer $token';
        }

        final uri = _baseUrl.resolve(path).replace(queryParameters: query);
        final response = switch (method) {
          'GET' => await _client.get(uri, headers: headers).timeout(timeout),
          'POST' =>
            await _client
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(timeout),
          'PUT' =>
            await _client
                .put(uri, headers: headers, body: jsonEncode(body))
                .timeout(timeout),
          _ => throw UnsupportedError('Unsupported method: $method'),
        };
        final payload = _decodeBody(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return payload;
        }
        if (response.statusCode == 401 &&
            authenticated &&
            !hasRefreshedAfterUnauthorized) {
          hasRefreshedAfterUnauthorized = true;
          forceRefreshNext = true;
          continue;
        }
        final problem = ApiProblem.fromJson(
          payload,
          status: response.statusCode,
          traceId: response.headers['x-correlation-id'],
        );
        if (!canRetryTransport || !problem.retryable || attempt == attempts) {
          throw problem;
        }
      } on TimeoutException {
        if (!canRetryTransport || attempt == attempts) {
          throw const NetworkUnavailable();
        }
      } on SocketException {
        if (!canRetryTransport || attempt == attempts) {
          throw const NetworkUnavailable();
        }
      } on http.ClientException {
        if (!canRetryTransport || attempt == attempts) {
          throw const NetworkUnavailable();
        }
      }
      await Future<void>.delayed(_backoff(attempt));
    }
    throw const NetworkUnavailable();
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object response.');
  }

  Duration _backoff(int attempt) =>
      Duration(milliseconds: 250 * (1 << (attempt - 1)));
}

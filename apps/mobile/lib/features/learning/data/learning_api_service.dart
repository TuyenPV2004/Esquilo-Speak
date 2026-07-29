import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class LearningApiService {
  LearningApiService(this._client, this._baseUrl);

  final http.Client _client;
  final Uri _baseUrl;
  final Uuid _uuid = const Uuid();
  String? _token;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
  }) async {
    final response = await _client.get(
      _uri(path, query),
      headers: await _headers(authenticated),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = false,
    bool idempotent = false,
  }) async {
    final headers = await _headers(authenticated);
    if (idempotent) {
      headers['Idempotency-Key'] = _uuid.v4();
    }
    final response = await _client.post(
      _uri(path),
      headers: headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUrl.resolve(path).replace(queryParameters: query);

  Future<Map<String, String>> _headers(bool authenticated) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      _token ??= await _localToken();
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<String> _localToken() async {
    final response = await _client.post(_uri('/internal/dev/token'));
    final payload = _decode(response);
    return payload['accessToken'] as String;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningApiException(
        code: payload['code'] as String? ?? 'HTTP_${response.statusCode}',
        message:
            payload['detail'] as String? ??
            'The learning service is unavailable.',
      );
    }
    return payload;
  }
}

class LearningApiException implements Exception {
  const LearningApiException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

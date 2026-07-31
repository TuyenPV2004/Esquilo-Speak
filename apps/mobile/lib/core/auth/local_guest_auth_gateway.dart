import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';

class LocalGuestAuthGateway implements AuthGateway {
  LocalGuestAuthGateway(this._client, this._baseUrl);

  final http.Client _client;
  final Uri _baseUrl;

  @override
  Future<AuthTokenSet> signIn() => _issueToken();

  @override
  Future<AuthTokenSet> refresh(AuthTokenSet current) => _issueToken();

  @override
  Future<void> endSession(AuthTokenSet current) async {}

  Future<AuthTokenSet> _issueToken() async {
    final response = await _client
        .post(_baseUrl.resolve('/internal/dev/token'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('The local guest session could not be created.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthTokenSet(
      accessToken: payload['accessToken'] as String,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }
}

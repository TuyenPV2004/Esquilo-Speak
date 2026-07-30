import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore(this._storage);

  static const _sessionKey = 'esquilospeak.auth.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);

  @override
  Future<AuthTokenSet?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      return AuthTokenSet.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokenSet tokens) =>
      _storage.write(key: _sessionKey, value: jsonEncode(tokens.toJson()));
}

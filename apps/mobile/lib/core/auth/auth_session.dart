import 'package:flutter/foundation.dart';

@immutable
class AuthTokenSet {
  const AuthTokenSet({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
  });

  factory AuthTokenSet.fromJson(Map<String, dynamic> json) => AuthTokenSet(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    idToken: json['idToken'] as String?,
    expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
  );

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime expiresAt;

  bool expiresWithin(Duration duration, DateTime now) =>
      !expiresAt.isAfter(now.toUtc().add(duration));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

abstract interface class AuthGateway {
  Future<AuthTokenSet> signIn();

  Future<AuthTokenSet> refresh(AuthTokenSet current);

  Future<void> endSession(AuthTokenSet current);
}

abstract interface class AuthTokenStore {
  Future<AuthTokenSet?> read();

  Future<void> write(AuthTokenSet tokens);

  Future<void> clear();
}

abstract interface class AccessTokenProvider {
  Future<String?> accessToken({bool forceRefresh = false});
}

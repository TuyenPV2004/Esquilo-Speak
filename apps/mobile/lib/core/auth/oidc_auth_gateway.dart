import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/app_environment.dart';
import 'auth_session.dart';

class OidcAuthGateway implements AuthGateway {
  OidcAuthGateway(this._environment, {this.appAuth = const FlutterAppAuth()}) {
    if (!_environment.hasOidcConfiguration) {
      throw StateError('External OIDC is not configured for this environment.');
    }
  }

  static const _scopes = ['openid', 'profile', 'offline_access', 'learning'];

  final AppEnvironment _environment;
  final FlutterAppAuth appAuth;

  @override
  Future<AuthTokenSet> signIn() async {
    final response = await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _environment.oidcClientId!,
        _environment.oidcRedirectUrl!.toString(),
        issuer: _environment.oidcIssuer!.toString(),
        scopes: _scopes,
      ),
    );
    return _tokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      idToken: response.idToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
  }

  @override
  Future<AuthTokenSet> refresh(AuthTokenSet current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null) {
      throw StateError('The OIDC session cannot be refreshed.');
    }
    final response = await appAuth.token(
      TokenRequest(
        _environment.oidcClientId!,
        _environment.oidcRedirectUrl!.toString(),
        issuer: _environment.oidcIssuer!.toString(),
        refreshToken: refreshToken,
        scopes: _scopes,
      ),
    );
    return _tokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken ?? refreshToken,
      idToken: response.idToken ?? current.idToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
  }

  @override
  Future<void> endSession(AuthTokenSet current) async {
    final idToken = current.idToken;
    if (idToken == null) return;
    await appAuth.endSession(
      EndSessionRequest(
        idTokenHint: idToken,
        issuer: _environment.oidcIssuer!.toString(),
        postLogoutRedirectUrl: _environment.oidcPostLogoutRedirectUrl
            ?.toString(),
      ),
    );
  }

  AuthTokenSet _tokens({
    required String? accessToken,
    required String? refreshToken,
    required String? idToken,
    required DateTime? expiresAt,
  }) {
    if (accessToken == null || expiresAt == null) {
      throw StateError('The identity provider returned an incomplete session.');
    }
    return AuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

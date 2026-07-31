import 'package:flutter/foundation.dart';

enum AppEnvironmentName { local, staging, production }

@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.name,
    required this.apiBaseUrl,
    required this.oidcIssuer,
    required this.oidcClientId,
    required this.oidcRedirectUrl,
    required this.oidcPostLogoutRedirectUrl,
    required this.closedTestingProductId,
  });

  factory AppEnvironment.fromDefines() {
    const configuredName = String.fromEnvironment(
      'ESQUILO_ENV',
      defaultValue: 'local',
    );
    final name = AppEnvironmentName.values.firstWhere(
      (candidate) => candidate.name == configuredName,
      orElse: () => throw StateError(
        'ESQUILO_ENV must be local, staging, or production.',
      ),
    );
    const configuredApiUrl = String.fromEnvironment('ESQUILO_API_URL');
    final apiUrl = configuredApiUrl.isNotEmpty
        ? configuredApiUrl
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
    const issuer = String.fromEnvironment('ESQUILO_OIDC_ISSUER');
    const clientId = String.fromEnvironment('ESQUILO_OIDC_CLIENT_ID');
    const redirectUrl = String.fromEnvironment('ESQUILO_OIDC_REDIRECT_URL');
    const postLogoutRedirectUrl = String.fromEnvironment(
      'ESQUILO_OIDC_POST_LOGOUT_REDIRECT_URL',
    );
    const closedTestingProductId = String.fromEnvironment(
      'ESQUILO_CLOSED_TEST_PRODUCT_ID',
      defaultValue: 'premium-monthly',
    );

    final environment = AppEnvironment(
      name: name,
      apiBaseUrl: Uri.parse(apiUrl),
      oidcIssuer: issuer.isEmpty ? null : Uri.parse(issuer),
      oidcClientId: clientId.isEmpty ? null : clientId,
      oidcRedirectUrl: redirectUrl.isEmpty ? null : Uri.parse(redirectUrl),
      oidcPostLogoutRedirectUrl: postLogoutRedirectUrl.isEmpty
          ? null
          : Uri.parse(postLogoutRedirectUrl),
      closedTestingProductId: closedTestingProductId,
    );
    environment.validate();
    return environment;
  }

  final AppEnvironmentName name;
  final Uri apiBaseUrl;
  final Uri? oidcIssuer;
  final String? oidcClientId;
  final Uri? oidcRedirectUrl;
  final Uri? oidcPostLogoutRedirectUrl;
  final String closedTestingProductId;

  bool get isLocal => name == AppEnvironmentName.local;

  bool get hasOidcConfiguration =>
      oidcIssuer != null && oidcClientId != null && oidcRedirectUrl != null;

  void validate() {
    if (!isLocal && apiBaseUrl.scheme != 'https') {
      throw StateError('Staging and production APIs must use HTTPS.');
    }
    if (isLocal) return;
    final configuredOidcValues = [
      oidcIssuer,
      oidcClientId,
      oidcRedirectUrl,
    ].where((value) => value != null).length;
    if (configuredOidcValues != 0 && configuredOidcValues != 3) {
      throw StateError(
        'OIDC issuer, client ID, and redirect URL must be configured together.',
      );
    }
    if (oidcIssuer != null && oidcIssuer!.scheme != 'https') {
      throw StateError('The external OIDC issuer must use HTTPS.');
    }
  }
}

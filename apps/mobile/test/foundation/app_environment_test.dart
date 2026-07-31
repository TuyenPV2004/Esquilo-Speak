import 'package:esquilospeak_mobile/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects cleartext outside the local environment', () {
    final environment = AppEnvironment(
      name: AppEnvironmentName.production,
      apiBaseUrl: Uri(scheme: 'http', host: 'api.example.test'),
      oidcIssuer: null,
      oidcClientId: null,
      oidcRedirectUrl: null,
      oidcPostLogoutRedirectUrl: null,
    );

    expect(environment.validate, throwsStateError);
  });

  test('accepts a complete HTTPS OIDC configuration', () {
    final environment = AppEnvironment(
      name: AppEnvironmentName.staging,
      apiBaseUrl: Uri(scheme: 'https', host: 'api.example.test'),
      oidcIssuer: Uri(scheme: 'https', host: 'identity.example.test'),
      oidcClientId: 'esquilospeak-mobile-staging',
      oidcRedirectUrl: Uri(
        scheme: 'com.esquilospeak.mobile.staging',
        host: 'oauthredirect',
      ),
      oidcPostLogoutRedirectUrl: null,
    );

    expect(environment.hasOidcConfiguration, isTrue);
    expect(environment.validate, returnsNormally);
  });
}

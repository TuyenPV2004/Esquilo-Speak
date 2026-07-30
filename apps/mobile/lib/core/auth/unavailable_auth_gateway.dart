import 'auth_session.dart';

class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  Future<AuthTokenSet> signIn() =>
      Future.error(StateError('External OIDC is not configured.'));

  @override
  Future<AuthTokenSet> refresh(AuthTokenSet current) =>
      Future.error(StateError('External OIDC is not configured.'));

  @override
  Future<void> endSession(AuthTokenSet current) async {}
}

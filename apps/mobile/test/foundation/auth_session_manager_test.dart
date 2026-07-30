import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/auth/auth_session_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshes an expiring token once and persists rotation', () async {
    final current = AuthTokenSet(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      expiresAt: DateTime.utc(2026, 7, 30, 10),
    );
    final refreshed = AuthTokenSet(
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresAt: DateTime.utc(2026, 7, 30, 11),
    );
    final store = _MemoryTokenStore(current);
    final gateway = _FakeGateway(refreshed);
    final manager = AuthSessionManager(
      gateway,
      store,
      now: () => DateTime.utc(2026, 7, 30, 9, 59, 30),
    );

    await manager.restore();
    final tokens = await Future.wait([
      manager.accessToken(),
      manager.accessToken(),
    ]);

    expect(tokens, everyElement('new-access'));
    expect(gateway.refreshCount, 1);
    expect(store.tokens?.refreshToken, 'new-refresh');
  });

  test('clears local credentials even when remote logout fails', () async {
    final store = _MemoryTokenStore(
      AuthTokenSet(
        accessToken: 'access',
        expiresAt: DateTime.utc(2026, 7, 30, 11),
      ),
    );
    final manager = AuthSessionManager(
      _FakeGateway(null, failLogout: true),
      store,
    );
    await manager.restore();

    await expectLater(manager.logout(), throwsStateError);

    expect(manager.isAuthenticated, isFalse);
    expect(store.tokens, isNull);
  });
}

class _MemoryTokenStore implements AuthTokenStore {
  _MemoryTokenStore(this.tokens);

  AuthTokenSet? tokens;

  @override
  Future<void> clear() async => tokens = null;

  @override
  Future<AuthTokenSet?> read() async => tokens;

  @override
  Future<void> write(AuthTokenSet tokens) async => this.tokens = tokens;
}

class _FakeGateway implements AuthGateway {
  _FakeGateway(this.refreshed, {this.failLogout = false});

  final AuthTokenSet? refreshed;
  final bool failLogout;
  int refreshCount = 0;

  @override
  Future<void> endSession(AuthTokenSet current) async {
    if (failLogout) throw StateError('remote logout failed');
  }

  @override
  Future<AuthTokenSet> refresh(AuthTokenSet current) async {
    refreshCount++;
    return refreshed!;
  }

  @override
  Future<AuthTokenSet> signIn() async => refreshed!;
}

import 'package:flutter/foundation.dart';

import 'auth_session.dart';

enum AuthSessionState { signedOut, restoring, active, refreshing }

class AuthSessionManager extends ChangeNotifier implements AccessTokenProvider {
  AuthSessionManager(
    this._gateway,
    this._store, {
    DateTime Function()? now,
    this.autoSignIn = false,
  }) : _now = now ?? DateTime.now;

  static const _refreshLeeway = Duration(minutes: 1);

  final AuthGateway _gateway;
  final AuthTokenStore _store;
  final DateTime Function() _now;
  final bool autoSignIn;

  AuthTokenSet? _tokens;
  Future<AuthTokenSet?>? _refreshInFlight;
  AuthSessionState state = AuthSessionState.signedOut;

  bool get isAuthenticated => _tokens != null;

  Future<void> restore() async {
    state = AuthSessionState.restoring;
    notifyListeners();
    _tokens = await _store.read();
    state = _tokens == null
        ? AuthSessionState.signedOut
        : AuthSessionState.active;
    notifyListeners();
  }

  Future<void> signIn() async {
    final tokens = await _gateway.signIn();
    await _store.write(tokens);
    _tokens = tokens;
    state = AuthSessionState.active;
    notifyListeners();
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    var current = _tokens;
    if (current == null && autoSignIn) {
      await signIn();
      current = _tokens;
    }
    if (current == null) return null;
    if (!forceRefresh &&
        !current.expiresWithin(_refreshLeeway, _now().toUtc())) {
      return current.accessToken;
    }
    final refreshed = await _refreshOnce();
    return refreshed?.accessToken;
  }

  Future<void> logout() async {
    final current = _tokens;
    _tokens = null;
    state = AuthSessionState.signedOut;
    notifyListeners();
    try {
      if (current != null) await _gateway.endSession(current);
    } finally {
      await _store.clear();
    }
  }

  Future<AuthTokenSet?> _refreshOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _refresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthTokenSet?> _refresh() async {
    final current = _tokens;
    if (current == null) return null;
    state = AuthSessionState.refreshing;
    notifyListeners();
    try {
      final refreshed = await _gateway.refresh(current);
      await _store.write(refreshed);
      _tokens = refreshed;
      state = AuthSessionState.active;
      notifyListeners();
      return refreshed;
    } on Object {
      await _store.clear();
      _tokens = null;
      state = AuthSessionState.signedOut;
      notifyListeners();
      rethrow;
    }
  }
}

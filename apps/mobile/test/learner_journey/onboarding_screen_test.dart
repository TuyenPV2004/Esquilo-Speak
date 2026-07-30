import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/auth/auth_session_manager.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/core/telemetry/app_telemetry.dart';
import 'package:esquilospeak_mobile/features/profile/data/learner_profile_models.dart';
import 'package:esquilospeak_mobile/features/profile/data/learner_profile_service.dart';
import 'package:esquilospeak_mobile/features/profile/presentation/learner_profile_view_model.dart';
import 'package:esquilospeak_mobile/features/profile/presentation/onboarding_screen.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('renders onboarding controls at large text', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(factory: databaseFactoryFfi);
    final client = MockClient((request) async => throw StateError('unused'));
    final session = AuthSessionManager(const _Gateway(), _TokenStore());
    final telemetry = ConsentAwareTelemetry(
      database,
      const NoOpTelemetrySink(),
    );
    final viewModel = LearnerProfileViewModel(
      LearnerProfileService(
        ApiClient(
          client,
          Uri.parse('https://api.example.test'),
          const _TokenProvider(),
        ),
        database,
      ),
      session,
      telemetry,
    );
    viewModel
      ..profile = LearnerProfile(
        learnerId: '22222222-2222-4222-8222-222222222222',
        actorType: LearnerActorType.guest,
        uiLocale: 'vi',
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        ageBand: null,
        learningGoal: null,
        preferences: const LearnerPreferences(),
        updatedAt: DateTime.utc(2026, 7, 30),
      )
      ..initialized = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: OnboardingScreen(viewModel: viewModel),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('A plan that fits your day'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

class _Gateway implements AuthGateway {
  const _Gateway();

  @override
  Future<void> endSession(AuthTokenSet current) async {}

  @override
  Future<AuthTokenSet> refresh(AuthTokenSet current) async => current;

  @override
  Future<AuthTokenSet> signIn() async => AuthTokenSet(
    accessToken: 'token',
    refreshToken: null,
    idToken: null,
    expiresAt: DateTime.utc(2026, 7, 31),
  );
}

class _TokenStore implements AuthTokenStore {
  AuthTokenSet? tokens;

  @override
  Future<void> clear() async => tokens = null;

  @override
  Future<AuthTokenSet?> read() async => tokens;

  @override
  Future<void> write(AuthTokenSet tokens) async => this.tokens = tokens;
}

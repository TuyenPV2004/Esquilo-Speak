import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/auth/auth_session.dart';
import '../core/auth/auth_session_manager.dart';
import '../core/auth/local_guest_auth_gateway.dart';
import '../core/auth/oidc_auth_gateway.dart';
import '../core/auth/secure_auth_token_store.dart';
import '../core/auth/unavailable_auth_gateway.dart';
import '../core/config/app_environment.dart';
import '../core/network/api_client.dart';
import '../core/localization/app_locale_controller.dart';
import '../core/platform/advanced_learning_platform.dart';
import '../core/storage/app_database.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/telemetry/app_telemetry.dart';
import '../features/learning/data/learning_api_service.dart';
import '../features/advanced_learning/data/p1_api_service.dart';
import '../features/advanced_learning/presentation/p1_view_model.dart';
import '../features/learning/data/offline_learning_repository.dart';
import '../features/learning/data/remote_learning_repository.dart';
import '../features/learning/presentation/learning_view_model.dart';
import '../features/profile/data/learner_profile_service.dart';
import '../features/profile/presentation/learner_profile_view_model.dart';
import '../features/review/data/learning_insights_service.dart';
import '../features/review/presentation/learning_insights_view_model.dart';

class AppDependencies {
  AppDependencies._({
    required this.environment,
    required this.httpClient,
    required this.database,
    required this.session,
    required this.telemetry,
    required this.sync,
    required this.learningViewModel,
    required this.profileViewModel,
    required this.insightsViewModel,
    required this.p1ViewModel,
    required this.localeController,
  });

  final AppEnvironment environment;
  final http.Client httpClient;
  final AppDatabase database;
  final AuthSessionManager session;
  final ConsentAwareTelemetry telemetry;
  final SyncCoordinator sync;
  final LearningViewModel learningViewModel;
  final LearnerProfileViewModel profileViewModel;
  final LearningInsightsViewModel insightsViewModel;
  final P1ViewModel p1ViewModel;
  final AppLocaleController localeController;

  static Future<AppDependencies> create() async {
    final environment = AppEnvironment.fromDefines();
    final httpClient = http.Client();
    final database = AppDatabase();
    await database.open();
    final localeController = AppLocaleController(database);
    await localeController.initialize();

    final gateway = _authGateway(environment, httpClient);
    final session = AuthSessionManager(
      gateway,
      SecureAuthTokenStore(const FlutterSecureStorage()),
      autoSignIn: environment.isLocal,
    );
    await session.restore();

    final telemetry = ConsentAwareTelemetry(
      database,
      const NoOpTelemetrySink(),
    );
    await telemetry.initialize();
    telemetry.installGlobalErrorHandlers();

    final api = ApiClient(httpClient, environment.apiBaseUrl, session);
    final sync = SyncCoordinator(database, api);
    final remoteRepository = RemoteLearningRepository(LearningApiService(api));
    final profileViewModel = LearnerProfileViewModel(
      LearnerProfileService(api, database),
      session,
      telemetry,
      localeController,
    );
    await profileViewModel.load();
    await localeController.setLanguageTag(profileViewModel.profile?.uiLocale);
    final learningViewModel = LearningViewModel(
      OfflineLearningRepository(remoteRepository, sync, database),
      learningContext: () {
        final profile = profileViewModel.profile;
        if (profile == null) return const LearningContextSnapshot.empty();
        return LearningContextSnapshot(
          sourceLanguage: profile.sourceLanguage,
          targetLanguage: profile.targetLanguage,
          activeCourseId: profile.activeCourseId,
        );
      },
      onCourseSelected: profileViewModel.setActiveCourse,
    )..loadCatalog();
    final insightsViewModel = LearningInsightsViewModel(
      LearningInsightsService(api, database),
    )..load();
    final p1ViewModel = P1ViewModel(
      P1ApiService(api),
      AndroidAdvancedLearningPlatform(environment, session),
      closedTestingCommerceEnabled: environment.isLocal,
      closedTestingProductId: environment.closedTestingProductId,
      selectedCourseId: () =>
          profileViewModel.profile?.activeCourseId ??
          learningViewModel.selectedCourse?.id,
    )..load();

    return AppDependencies._(
      environment: environment,
      httpClient: httpClient,
      database: database,
      session: session,
      telemetry: telemetry,
      sync: sync,
      learningViewModel: learningViewModel,
      profileViewModel: profileViewModel,
      insightsViewModel: insightsViewModel,
      p1ViewModel: p1ViewModel,
      localeController: localeController,
    );
  }

  static AuthGateway _authGateway(
    AppEnvironment environment,
    http.Client client,
  ) {
    if (environment.isLocal) {
      return LocalGuestAuthGateway(client, environment.apiBaseUrl);
    }
    if (environment.hasOidcConfiguration) {
      return OidcAuthGateway(environment);
    }
    return const UnavailableAuthGateway();
  }

  Future<void> dispose() async {
    learningViewModel.dispose();
    profileViewModel.dispose();
    insightsViewModel.dispose();
    p1ViewModel.dispose();
    localeController.dispose();
    session.dispose();
    httpClient.close();
    await database.close();
  }
}

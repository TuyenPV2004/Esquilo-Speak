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
import '../core/storage/app_database.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/telemetry/app_telemetry.dart';
import '../features/learning/data/learning_api_service.dart';
import '../features/learning/data/offline_learning_repository.dart';
import '../features/learning/data/remote_learning_repository.dart';
import '../features/learning/presentation/learning_view_model.dart';

class AppDependencies {
  AppDependencies._({
    required this.environment,
    required this.httpClient,
    required this.database,
    required this.session,
    required this.telemetry,
    required this.sync,
    required this.learningViewModel,
  });

  final AppEnvironment environment;
  final http.Client httpClient;
  final AppDatabase database;
  final AuthSessionManager session;
  final ConsentAwareTelemetry telemetry;
  final SyncCoordinator sync;
  final LearningViewModel learningViewModel;

  static Future<AppDependencies> create() async {
    final environment = AppEnvironment.fromDefines();
    final httpClient = http.Client();
    final database = AppDatabase();
    await database.open();

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
    final learningViewModel = LearningViewModel(
      OfflineLearningRepository(remoteRepository, sync),
    )..loadCatalog();

    return AppDependencies._(
      environment: environment,
      httpClient: httpClient,
      database: database,
      session: session,
      telemetry: telemetry,
      sync: sync,
      learningViewModel: learningViewModel,
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
    session.dispose();
    httpClient.close();
    await database.close();
  }
}

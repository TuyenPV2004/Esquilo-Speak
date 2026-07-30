import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_problem.dart';
import '../../../core/storage/app_database.dart';
import 'learner_profile_models.dart';

class LearnerProfileService {
  LearnerProfileService(this._api, this._database, {this.uuid = const Uuid()});

  static const telemetryPolicyVersion = 'telemetry-p0-v1';

  final ApiClient _api;
  final AppDatabase _database;
  final Uuid uuid;

  Future<LearnerProfile> profile() async {
    try {
      final payload = await _api.get(
        '/api/mobile/v1/me/profile',
        authenticated: true,
      );
      await _database.cacheJson('learner.profile', payload);
      return LearnerProfile.fromJson(payload);
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson('learner.profile');
      if (cached == null) rethrow;
      return LearnerProfile.fromJson(cached);
    }
  }

  Future<LearnerProfile> updateProfile({
    required String uiLocale,
    required String sourceLanguage,
    required String targetLanguage,
    required LearnerAgeBand ageBand,
    required String learningGoal,
    required LearnerPreferences preferences,
  }) async {
    final payload = await _api.put(
      '/api/mobile/v1/me/profile',
      authenticated: true,
      body: {
        'uiLocale': uiLocale,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'ageBand': ageBand.apiValue,
        'learningGoal': learningGoal,
        'preferences': preferences.toJson(),
      },
    );
    await _database.cacheJson('learner.profile', payload);
    return LearnerProfile.fromJson(payload);
  }

  Future<List<ConsentRecord>> consents() async {
    try {
      final response = await _api.get(
        '/api/mobile/v1/me/consents',
        authenticated: true,
      );
      await _database.cacheJson('learner.consents', response);
      return _decodeConsents(response);
    } on Object catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _database.cachedJson('learner.consents');
      if (cached == null) rethrow;
      return _decodeConsents(cached);
    }
  }

  Future<ConsentRecord> setTelemetryConsent(bool granted) async {
    final record = ConsentRecord.fromJson(
      await _api.put(
        '/api/mobile/v1/me/consents/operational_telemetry',
        authenticated: true,
        body: {'policyVersion': telemetryPolicyVersion, 'granted': granted},
      ),
    );
    final current = await consents();
    await _database.cacheJson('learner.consents', {
      'items': [
        ...current
            .where((item) => item.purpose != record.purpose)
            .map((item) => item.toJson()),
        record.toJson(),
      ],
    });
    return record;
  }

  Future<PrivacyRequest> requestExport() =>
      _privacyRequest('/api/mobile/v1/me/privacy/exports');

  Future<PrivacyRequest> requestDeletion() =>
      _privacyRequest('/api/mobile/v1/me/privacy/deletions');

  Future<PrivacyRequest> _privacyRequest(String path) async =>
      PrivacyRequest.fromJson(
        await _api.post(
          path,
          authenticated: true,
          idempotencyKey: uuid.v4(),
          body: const {},
        ),
      );

  List<ConsentRecord> _decodeConsents(Map<String, dynamic> payload) =>
      (payload['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ConsentRecord.fromJson)
          .toList(growable: false);

  bool _canUseCache(Object error) =>
      error is NetworkUnavailable || (error is ApiProblem && error.retryable);
}

import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/features/profile/data/learner_profile_models.dart';
import 'package:esquilospeak_mobile/features/profile/data/learner_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'loads onboarding state and persists profile, consent, and export',
    () async {
      final database = AppDatabase(factory: databaseFactoryFfi);
      await database.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path.endsWith('/profile')) {
          return _json(_profile());
        }
        if (request.method == 'GET' && request.url.path.endsWith('/consents')) {
          return _json({
            'items': [
              {
                'purpose': 'required_service',
                'policyVersion': 'required-p0-v1',
                'granted': true,
                'recordedAt': '2026-07-30T00:00:00Z',
              },
            ],
          });
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/profile')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['sourceLanguage'], 'vi');
          expect(body['targetLanguage'], 'en');
          expect(body['ageBand'], 'adult');
          expect(
            (body['preferences'] as Map<String, dynamic>)['dailyGoalMinutes'],
            10,
          );
          return _json(_profile(ageBand: 'adult'));
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/operational_telemetry')) {
          return _json({
            'purpose': 'operational_telemetry',
            'policyVersion': 'telemetry-p0-v1',
            'granted': true,
            'recordedAt': '2026-07-30T00:01:00Z',
          });
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/privacy/exports')) {
          return _json({
            'requestId': '11111111-1111-4111-8111-111111111111',
            'requestType': 'export',
            'state': 'requested',
            'requestedAt': '2026-07-30T00:02:00Z',
            'targetAt': '2026-08-29T00:02:00Z',
          }, status: 202);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });
      final service = LearnerProfileService(
        ApiClient(
          client,
          Uri.parse('https://api.example.test'),
          const _TokenProvider(),
        ),
        database,
      );

      final profile = await service.profile();
      expect(profile.actorType, LearnerActorType.guest);
      expect(profile.onboardingComplete, isFalse);

      final updated = await service.updateProfile(
        uiLocale: 'vi',
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        ageBand: LearnerAgeBand.adult,
        learningGoal: 'daily_communication',
        preferences: const LearnerPreferences(dailyGoalMinutes: 10),
      );
      expect(updated.onboardingComplete, isTrue);

      final consent = await service.setTelemetryConsent(true);
      expect(consent.granted, isTrue);

      final export = await service.requestExport();
      expect(export.requestType, 'export');
      expect(requests.last.headers['Idempotency-Key'], isNotEmpty);
    },
  );
}

Map<String, dynamic> _profile({String? ageBand}) => {
  'learnerId': '22222222-2222-4222-8222-222222222222',
  'actorType': 'guest',
  'uiLocale': 'vi',
  'sourceLanguage': 'vi',
  'targetLanguage': 'en',
  'ageBand': ?ageBand,
  'learningGoal': 'daily_communication',
  'preferences': {'dailyGoalMinutes': 10, 'notificationsEnabled': false},
  'updatedAt': '2026-07-30T00:00:00Z',
};

http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

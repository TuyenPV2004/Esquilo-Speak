import 'dart:async';
import 'dart:convert';

import 'package:esquilospeak_mobile/core/auth/auth_session.dart';
import 'package:esquilospeak_mobile/core/network/api_client.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:esquilospeak_mobile/core/telemetry/app_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'consent gates events and the API payload contains only allowlisted data',
    () async {
      final database = AppDatabase(factory: databaseFactoryFfi);
      await database.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final payloads = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          '{"accepted":1,"duplicates":0,"retentionPolicyVersion":1,"retentionDays":30}',
          200,
        );
      });
      addTearDown(client.close);
      final telemetry = ConsentAwareTelemetry(
        database,
        ApiTelemetrySink(
          ApiClient(
            client,
            Uri.parse('https://api.example.test'),
            const _TokenProvider(),
            maxAttempts: 1,
          ),
        ),
      );
      await telemetry.initialize();
      await telemetry.event('lesson_started', {'lessonId': 'lesson-1'});
      expect(payloads, isEmpty);

      await telemetry.setConsent(true);
      await telemetry.event('exercise_submitted', {
        'courseId': 'course-1',
        'lessonId': 'lesson-1',
        'exerciseId': 'exercise-1',
        'exerciseType': 'multiple_choice',
        'correct': true,
        'hintUsed': false,
        'rawAnswer': 'must-not-leave-device',
      });
      await Future<void>.delayed(Duration.zero);

      final event =
          (payloads.single['events'] as List).single as Map<String, dynamic>;
      expect(event['courseId'], 'course-1');
      expect(event['lessonId'], 'lesson-1');
      expect(event['exerciseId'], 'exercise-1');
      expect(event['attributes'], {'correct': true, 'hintUsed': false});
      expect(jsonEncode(payloads.single), isNot(contains('rawAnswer')));
      expect(
        jsonEncode(payloads.single),
        isNot(contains('must-not-leave-device')),
      );
    },
  );

  test(
    'a blocked analytics transport never blocks the product caller',
    () async {
      final database = AppDatabase(factory: databaseFactoryFfi);
      await database.open(path: inMemoryDatabasePath);
      addTearDown(database.close);
      final sink = _BlockingSink();
      final telemetry = ConsentAwareTelemetry(database, sink);
      await telemetry.initialize();
      await telemetry.setConsent(true);

      await telemetry
          .event('lesson_started', {'lessonId': 'lesson-1'})
          .timeout(const Duration(milliseconds: 100));

      expect(sink.started, isTrue);
    },
  );
}

class _TokenProvider implements AccessTokenProvider {
  const _TokenProvider();

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'token';
}

class _BlockingSink implements TelemetrySink {
  final Completer<void> _never = Completer<void>();
  bool started = false;

  @override
  Future<void> event(String name, Map<String, Object?> attributes) {
    started = true;
    return _never.future;
  }

  @override
  Future<void> exception(String category, {bool fatal = false}) async {}
}

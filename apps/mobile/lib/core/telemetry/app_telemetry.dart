import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../storage/app_database.dart';

abstract interface class TelemetrySink {
  Future<void> event(String name, Map<String, Object?> attributes);

  Future<void> exception(String category, {bool fatal = false});
}

class NoOpTelemetrySink implements TelemetrySink {
  const NoOpTelemetrySink();

  @override
  Future<void> event(String name, Map<String, Object?> attributes) async {}

  @override
  Future<void> exception(String category, {bool fatal = false}) async {}
}

class ApiTelemetrySink implements TelemetrySink {
  ApiTelemetrySink(this._api, {this.uuid = const Uuid()});

  static const _structuredKeys = {
    'courseId',
    'unitId',
    'lessonId',
    'lessonVersion',
    'exerciseId',
    'exerciseType',
    'sessionKind',
  };

  final ApiClient _api;
  final Uuid uuid;

  @override
  Future<void> event(String name, Map<String, Object?> attributes) async {
    final clientEventId = uuid.v4();
    final event = <String, dynamic>{
      'clientEventId': clientEventId,
      'name': name,
      'eventVersion': 1,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      for (final key in _structuredKeys)
        if (attributes[key] != null) key: attributes[key],
      'attributes': {
        for (final entry in attributes.entries)
          if (!_structuredKeys.contains(entry.key) && entry.value != null)
            entry.key: entry.value,
      },
    };
    try {
      await _api.post(
        '/api/mobile/v1/analytics/events',
        authenticated: true,
        idempotencyKey: clientEventId,
        body: {
          'events': [event],
        },
      );
    } on Object {
      // Analytics is best-effort and must never block the learning journey.
    }
  }

  @override
  Future<void> exception(String category, {bool fatal = false}) async {
    // Crash transport remains a separate operational boundary; product analytics
    // intentionally accepts no stack trace, exception message, or arbitrary type.
  }
}

class ConsentAwareTelemetry {
  ConsentAwareTelemetry(this._database, this._sink);

  static const _consentKey = 'operational_telemetry_consent';
  static const _allowedAttributes = {
    'screen',
    'operation',
    'result',
    'environment',
    'durationBucket',
    'courseId',
    'unitId',
    'lessonId',
    'lessonVersion',
    'exerciseId',
    'exerciseType',
    'sessionKind',
    'reasonCode',
    'practiceMode',
    'retryIndex',
    'hintUsed',
    'responseTimeBucket',
    'correct',
    'feedbackHelpful',
    'recommendationPolicyVersion',
    'recommendationKind',
    'usedFallback',
  };

  final AppDatabase _database;
  final TelemetrySink _sink;
  bool _enabled = false;

  Future<void> initialize() async {
    _enabled = await _database.booleanSetting(_consentKey);
  }

  Future<void> setConsent(bool enabled) async {
    await _database.setBooleanSetting(_consentKey, enabled);
    _enabled = enabled;
  }

  Future<void> event(String name, Map<String, Object?> attributes) async {
    if (!_enabled) return;
    final sanitized = Map<String, Object?>.fromEntries(
      attributes.entries.where(
        (entry) =>
            _allowedAttributes.contains(entry.key) &&
            (entry.value == null ||
                entry.value is String ||
                entry.value is num ||
                entry.value is bool),
      ),
    );
    unawaited(_deliverEvent(name, sanitized));
  }

  Future<void> exception(Object error, {bool fatal = false}) async {
    if (!_enabled) return;
    unawaited(_deliverException(error.runtimeType.toString(), fatal: fatal));
  }

  Future<void> _deliverEvent(
    String name,
    Map<String, Object?> attributes,
  ) async {
    try {
      await _sink.event(name, attributes);
    } on Object {
      // Telemetry transport is isolated from product behavior.
    }
  }

  Future<void> _deliverException(String category, {required bool fatal}) async {
    try {
      await _sink.exception(category, fatal: fatal);
    } on Object {
      // Error reporting must not create a second application error.
    }
  }

  void installGlobalErrorHandlers() {
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previousFlutterHandler == null) {
        FlutterError.presentError(details);
      } else {
        previousFlutterHandler(details);
      }
      exception(details.exception);
    };
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      exception(error, fatal: true);
      return previousPlatformHandler?.call(error, stack) ?? false;
    };
  }
}

import 'package:flutter/foundation.dart';

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

class ConsentAwareTelemetry {
  ConsentAwareTelemetry(this._database, this._sink);

  static const _consentKey = 'operational_telemetry_consent';
  static const _allowedAttributes = {
    'screen',
    'operation',
    'result',
    'environment',
    'durationBucket',
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
    await _sink.event(name, sanitized);
  }

  Future<void> exception(Object error, {bool fatal = false}) async {
    if (!_enabled) return;
    await _sink.exception(error.runtimeType.toString(), fatal: fatal);
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

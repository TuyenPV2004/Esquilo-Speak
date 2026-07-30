import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../config/app_environment.dart';

abstract interface class AdvancedLearningPlatform {
  Future<void> playRemoteMedia(String mediaId);

  Future<void> downloadMedia(String mediaId);

  Future<void> playDownloadedMedia(String mediaId);

  Future<bool> requestMicrophonePermission();

  Future<void> startRecording();

  Future<String> stopRecording();

  Future<bool> requestNotificationPermission();

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  Future<void> cancelDailyReminder();
}

class AndroidAdvancedLearningPlatform implements AdvancedLearningPlatform {
  AndroidAdvancedLearningPlatform(
    this._environment,
    this._tokens, {
    this._channel = const MethodChannel(
      'com.esquilospeak.mobile/advanced_learning',
    ),
  });

  final AppEnvironment _environment;
  final AccessTokenProvider _tokens;
  final MethodChannel _channel;

  @override
  Future<void> playRemoteMedia(String mediaId) async {
    await _channel.invokeMethod<void>('playRemoteMedia', {
      'url': _mediaUri(mediaId).toString(),
      'token': await _requiredToken(),
    });
  }

  @override
  Future<void> downloadMedia(String mediaId) async {
    await _channel.invokeMethod<void>('downloadMedia', {
      'url': _mediaUri(mediaId).toString(),
      'mediaId': mediaId,
      'token': await _requiredToken(),
    });
  }

  @override
  Future<void> playDownloadedMedia(String mediaId) =>
      _channel.invokeMethod<void>('playDownloadedMedia', {'mediaId': mediaId});

  @override
  Future<bool> requestMicrophonePermission() async =>
      await _channel.invokeMethod<bool>('requestMicrophonePermission') ?? false;

  @override
  Future<void> startRecording() =>
      _channel.invokeMethod<void>('startRecording');

  @override
  Future<String> stopRecording() async {
    final value = await _channel.invokeMethod<String>('stopRecording');
    if (value == null || value.isEmpty) {
      throw StateError('The recording did not contain audio.');
    }
    return value;
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) => _channel.invokeMethod<void>('scheduleDailyReminder', {
    'hour': hour,
    'minute': minute,
    'title': title,
    'body': body,
  });

  @override
  Future<void> cancelDailyReminder() =>
      _channel.invokeMethod<void>('cancelDailyReminder');

  Uri _mediaUri(String mediaId) =>
      _environment.apiBaseUrl.resolve('/api/mobile/v1/media/$mediaId');

  Future<String> _requiredToken() async {
    final token = await _tokens.accessToken();
    if (token == null) throw StateError('A learner session is required.');
    return token;
  }
}

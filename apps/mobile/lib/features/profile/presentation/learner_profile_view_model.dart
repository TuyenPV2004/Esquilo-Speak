import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/network/user_facing_failure.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../data/learner_profile_models.dart';
import '../data/learner_profile_service.dart';

class LearnerProfileViewModel extends ChangeNotifier {
  LearnerProfileViewModel(this._service, this._session, this._telemetry);

  final LearnerProfileService _service;
  final AuthSessionManager _session;
  final ConsentAwareTelemetry _telemetry;

  LearnerProfile? profile;
  List<ConsentRecord> consents = const [];
  PrivacyRequest? privacyRequest;
  UserFacingFailure? failure;
  bool loading = false;
  bool saving = false;
  bool initialized = false;

  bool get needsOnboarding => profile != null && !profile!.onboardingComplete;

  bool get telemetryConsent => consents.any(
    (item) => item.purpose == 'operational_telemetry' && item.granted,
  );

  Future<void> load() async {
    loading = true;
    failure = null;
    notifyListeners();
    try {
      profile = await _service.profile();
      consents = await _service.consents();
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    saving = true;
    failure = null;
    notifyListeners();
    try {
      await _session.signIn();
      await load();
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> completeOnboarding({
    required LearnerAgeBand ageBand,
    required String learningGoal,
    required int dailyGoalMinutes,
    required bool notificationsEnabled,
  }) async {
    saving = true;
    failure = null;
    notifyListeners();
    try {
      profile = await _service.updateProfile(
        uiLocale: 'vi',
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        ageBand: ageBand,
        learningGoal: learningGoal,
        preferences: LearnerPreferences(
          dailyGoalMinutes: dailyGoalMinutes,
          notificationsEnabled: notificationsEnabled,
        ),
      );
      return true;
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> setTelemetryConsent(bool enabled) async {
    saving = true;
    failure = null;
    notifyListeners();
    try {
      final record = await _service.setTelemetryConsent(enabled);
      consents = [
        ...consents.where((item) => item.purpose != 'operational_telemetry'),
        record,
      ];
      await _telemetry.setConsent(enabled);
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> requestExport() => _request(_service.requestExport);

  Future<void> requestDeletion() => _request(_service.requestDeletion);

  Future<void> _request(Future<PrivacyRequest> Function() action) async {
    saving = true;
    failure = null;
    notifyListeners();
    try {
      privacyRequest = await action();
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _session.logout();
    profile = null;
    consents = const [];
    privacyRequest = null;
    initialized = true;
    notifyListeners();
  }
}

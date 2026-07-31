import 'package:flutter/foundation.dart';

import '../../../core/network/user_facing_failure.dart';
import '../../../core/platform/advanced_learning_platform.dart';
import '../data/p1_api_service.dart';
import '../data/p1_models.dart';

enum P1PermissionIssue { microphone, notifications }

class P1ViewModel extends ChangeNotifier {
  P1ViewModel(
    this._gateway,
    this._platform, {
    required this.closedTestingCommerceEnabled,
    required this.closedTestingProductId,
    required this.selectedCourseId,
  });

  final P1Gateway _gateway;
  final AdvancedLearningPlatform _platform;
  final String? Function() selectedCourseId;
  final bool closedTestingCommerceEnabled;
  final String closedTestingProductId;

  bool busy = false;
  bool recording = false;
  bool courseSelectionRequired = false;
  UserFacingFailure? failure;
  P1PermissionIssue? permissionIssue;
  AdvancedFeedback? pronunciationFeedback;
  AdvancedFeedback? writingFeedback;
  AdvancedFeedback? conversationFeedback;
  PlacementAssessment? assessment;
  PlacementResult? placementResult;
  EngagementStatus? engagement;
  Entitlement? entitlement;
  SupportTicket? supportTicket;
  final Map<String, String> assessmentAnswers = {};
  final Set<String> downloadedMediaIds = {};
  List<AdvancedActivityDefinition> advancedActivities = const [];

  AdvancedActivityDefinition? get activeActivity =>
      advancedActivities.firstOrNull;

  Future<void> load() async {
    await _run(() async {
      engagement = await _gateway.getEngagement();
      final courseId = selectedCourseId();
      advancedActivities = courseId == null
          ? const []
          : await _gateway.advancedActivities(courseId);
      await _loadPlacementIfAvailable();
    });
  }

  Future<void> loadPlacement() => _run(_loadPlacementIfAvailable);

  Future<void> _loadPlacementIfAvailable() async {
    final courseId = selectedCourseId();
    if (courseId == null) {
      courseSelectionRequired = true;
      assessment = null;
      return;
    }
    courseSelectionRequired = false;
    if (assessment?.courseId == courseId) return;
    assessmentAnswers.clear();
    placementResult = null;
    assessment = await _gateway.getPlacement(courseId);
  }

  Future<void> playMedia(String mediaId) => _run(
    () => downloadedMediaIds.contains(mediaId)
        ? _platform.playDownloadedMedia(mediaId)
        : _platform.playRemoteMedia(mediaId),
  );

  Future<void> downloadMedia(String mediaId) => _run(() async {
    await _platform.downloadMedia(mediaId);
    downloadedMediaIds.add(mediaId);
  });

  Future<void> startPronunciationRecording() async {
    await _run(() async {
      final allowed = await _platform.requestMicrophonePermission();
      if (!allowed) {
        permissionIssue = P1PermissionIssue.microphone;
        return;
      }
      await _platform.startRecording();
      recording = true;
    });
  }

  Future<void> stopAndAssessPronunciation({
    required String expectedText,
    required String locale,
  }) => _run(() async {
    final audio = await _platform.stopRecording();
    recording = false;
    pronunciationFeedback = await _gateway.assessPronunciation(
      audioBase64: audio,
      expectedText: expectedText,
      locale: locale,
    );
  }, keepRecordingStateOnError: false);

  Future<void> requestTextFeedback({
    required String kind,
    required String input,
    required String locale,
  }) => _run(() async {
    final activity = activeActivity;
    if (activity == null) {
      failure = UserFacingFailure.unavailable;
      return;
    }
    final feedback = await _gateway.textFeedback(
      kind: kind,
      contentRef: activity.contentRef,
      input: input,
      locale: locale,
    );
    if (kind == 'writing') {
      writingFeedback = feedback;
    } else {
      conversationFeedback = feedback;
    }
  });

  void selectAssessmentAnswer(String questionId, String answer) {
    assessmentAnswers[questionId] = answer;
    notifyListeners();
  }

  void resetPlacement() {
    placementResult = null;
    assessmentAnswers.clear();
    failure = null;
    notifyListeners();
  }

  Future<void> submitPlacement() => _run(() async {
    final current = assessment;
    if (current == null ||
        current.questions.any(
          (question) => !assessmentAnswers.containsKey(question.id),
        )) {
      failure = UserFacingFailure.unexpected;
      return;
    }
    placementResult = await _gateway.submitPlacement(
      assessmentId: current.id,
      answers: current.questions
          .map((question) => assessmentAnswers[question.id]!)
          .toList(growable: false),
    );
  });

  Future<void> recordLearningActivity() => _run(() async {
    final activity = activeActivity;
    if (activity == null) {
      failure = UserFacingFailure.unavailable;
      return;
    }
    engagement = await _gateway.recordActivity(
      eventType: 'advanced_practice_completed',
      evidenceRef: activity.id,
    );
  });

  Future<void> updateReminder({
    required bool enabled,
    required String locale,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) => _run(() async {
    if (enabled) {
      final allowed = await _platform.requestNotificationPermission();
      if (!allowed) {
        permissionIssue = P1PermissionIssue.notifications;
        return;
      }
    }
    await _gateway.updateReminder(
      enabled: enabled,
      reminderTime:
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
      locale: locale,
      timezone: await _platform.systemTimezone(),
    );
    if (enabled) {
      await _platform.scheduleDailyReminder(
        hour: hour,
        minute: minute,
        title: title,
        body: body,
      );
    } else {
      await _platform.cancelDailyReminder();
    }
    engagement = await _gateway.getEngagement();
  });

  Future<void> purchasePremium() => _run(() async {
    if (!closedTestingCommerceEnabled) {
      failure = UserFacingFailure.unavailable;
      return;
    }
    entitlement = await _gateway.verifyClosedTestingPurchase(
      closedTestingProductId,
    );
  });

  Future<void> refundPremium() => _run(() async {
    if (!closedTestingCommerceEnabled) {
      failure = UserFacingFailure.unavailable;
      return;
    }
    entitlement = await _gateway.refundLatestClosedTestingPurchase(
      closedTestingProductId,
    );
  });

  Future<void> submitSupport({
    required bool contentReport,
    required String contentRef,
    required String locale,
    required String description,
  }) => _run(() async {
    supportTicket = await _gateway.createSupportTicket(
      type: contentReport ? 'content_report' : 'support',
      contentRef: contentReport ? contentRef : null,
      locale: locale,
      description: description,
    );
  });

  void clearFailure() {
    failure = null;
    permissionIssue = null;
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool keepRecordingStateOnError = true,
  }) async {
    if (busy) return;
    busy = true;
    failure = null;
    permissionIssue = null;
    notifyListeners();
    try {
      await operation();
    } on Object catch (error) {
      failure = mapUserFacingFailure(error);
      if (!keepRecordingStateOnError) recording = false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

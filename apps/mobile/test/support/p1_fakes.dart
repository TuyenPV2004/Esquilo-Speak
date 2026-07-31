import 'package:esquilospeak_mobile/core/platform/advanced_learning_platform.dart';
import 'package:esquilospeak_mobile/core/models/proficiency_models.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/data/p1_api_service.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/data/p1_models.dart';

class FakeP1Gateway implements P1Gateway {
  int activities = 0;
  bool reminderEnabled = false;
  bool premiumActive = false;

  @override
  Future<List<AdvancedActivityDefinition>> advancedActivities(
    String courseId,
  ) async => const [
    AdvancedActivityDefinition(
      id: 'activity-basic-greetings',
      contentRef: 'lesson-basic-greetings@1',
      mediaId: 'a1-hello',
      expectedText: 'Hello, my name is Ana.',
      targetLocale: 'en',
      feedbackLocale: 'vi',
    ),
  ];

  @override
  Future<AdvancedFeedback> assessPronunciation({
    required String audioBase64,
    required String expectedText,
    required String locale,
  }) async => AdvancedFeedback(
    id: 'feedback-pronunciation',
    kind: 'pronunciation',
    transcript: expectedText,
    score: 88,
    feedback: const {'summary': 'Clear pronunciation.'},
    provider: 'test',
    createdAt: DateTime.utc(2026, 7, 30),
  );

  @override
  Future<SupportTicket> createSupportTicket({
    required String type,
    required String? contentRef,
    required String locale,
    required String description,
  }) async => SupportTicket(
    id: 'ticket-1',
    type: type,
    contentRef: contentRef,
    locale: locale,
    description: description,
    status: 'open',
    createdAt: DateTime.utc(2026, 7, 30),
  );

  @override
  Future<EngagementStatus> getEngagement() async => EngagementStatus(
    currentStreak: activities == 0 ? 0 : 1,
    longestStreak: activities == 0 ? 0 : 1,
    xp: activities * 15,
    achievements: activities == 0
        ? const []
        : [
            Achievement(
              code: 'first-step',
              earnedAt: DateTime.utc(2026, 7, 30),
            ),
          ],
    reminderEnabled: reminderEnabled,
    reminderTime: reminderEnabled ? '19:30:00' : null,
    timezone: 'Asia/Ho_Chi_Minh',
  );

  @override
  Future<PlacementAssessment> getPlacement(String courseId) async =>
      PlacementAssessment(
        id: 'placement-a1-v1',
        courseId: courseId,
        proficiency: const ProficiencyReference(
          frameworkCode: 'cefr',
          frameworkVersion: '2020',
          levelCode: 'A1',
        ),
        passScore: 80,
        questions: [
          PlacementQuestion(
            id: 'q1',
            prompt: 'Greeting',
            options: ['hello', 'later', 'thanks'],
          ),
          PlacementQuestion(
            id: 'q2',
            prompt: 'Name',
            options: ['name', 'day', 'food'],
          ),
          PlacementQuestion(
            id: 'q3',
            prompt: 'Three',
            options: ['two', 'three', 'four'],
          ),
          PlacementQuestion(
            id: 'q4',
            prompt: 'Farewell',
            options: ['goodbye', 'please', 'water'],
          ),
        ],
      );

  @override
  Future<EngagementStatus> recordActivity({
    required String eventType,
    required String evidenceRef,
  }) async {
    activities++;
    return getEngagement();
  }

  @override
  Future<Entitlement> refundLatestClosedTestingPurchase(
    String productId,
  ) async {
    premiumActive = false;
    return _entitlement();
  }

  @override
  Future<PlacementResult> submitPlacement({
    required String assessmentId,
    required List<String> answers,
  }) async => PlacementResult(
    score: 100,
    passed: true,
    proficiency: const ProficiencyReference(
      frameworkCode: 'cefr',
      frameworkVersion: '2020',
      levelCode: 'A1',
    ),
    completedAt: DateTime.utc(2026, 7, 30),
    hasCompletionRecord: true,
  );

  @override
  Future<AdvancedFeedback> textFeedback({
    required String kind,
    required String contentRef,
    required String input,
    required String locale,
  }) async => AdvancedFeedback(
    id: 'feedback-$kind',
    kind: kind,
    feedback: const {'summary': 'Clear response with enough detail.'},
    provider: 'test',
    createdAt: DateTime.utc(2026, 7, 30),
  );

  @override
  Future<void> updateReminder({
    required bool enabled,
    required String reminderTime,
    required String locale,
    required String timezone,
  }) async {
    reminderEnabled = enabled;
  }

  @override
  Future<Entitlement> verifyClosedTestingPurchase(String productId) async {
    premiumActive = true;
    return _entitlement();
  }

  Entitlement _entitlement() => Entitlement(
    code: 'premium',
    status: premiumActive ? 'active' : 'revoked',
    source: 'google_play',
    updatedAt: DateTime.utc(2026, 7, 30),
  );
}

class FakeAdvancedLearningPlatform implements AdvancedLearningPlatform {
  @override
  Future<String> systemTimezone() async => 'Asia/Ho_Chi_Minh';
  bool microphoneAllowed = true;
  bool notificationAllowed = true;
  bool recording = false;
  bool reminderScheduled = false;
  final Set<String> downloads = {};
  final List<String> played = [];

  @override
  Future<void> cancelDailyReminder() async {
    reminderScheduled = false;
  }

  @override
  Future<void> downloadMedia(String mediaId) async {
    downloads.add(mediaId);
  }

  @override
  Future<void> playDownloadedMedia(String mediaId) async {
    played.add('downloaded:$mediaId');
  }

  @override
  Future<void> playRemoteMedia(String mediaId) async {
    played.add('remote:$mediaId');
  }

  @override
  Future<bool> requestMicrophonePermission() async => microphoneAllowed;

  @override
  Future<bool> requestNotificationPermission() async => notificationAllowed;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    reminderScheduled = true;
  }

  @override
  Future<void> startRecording() async {
    recording = true;
  }

  @override
  Future<String> stopRecording() async {
    recording = false;
    return 'dGVzdC1hdWRpbw==';
  }
}

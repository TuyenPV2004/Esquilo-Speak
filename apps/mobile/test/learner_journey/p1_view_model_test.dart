import 'package:esquilospeak_mobile/features/advanced_learning/presentation/p1_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/p1_fakes.dart';

void main() {
  test(
    'coordinates media, recording and derived pronunciation feedback',
    () async {
      final gateway = FakeP1Gateway();
      final platform = FakeAdvancedLearningPlatform();
      final viewModel = P1ViewModel(
        gateway,
        platform,
        closedTestingCommerceEnabled: true,
      );

      await viewModel.downloadMedia('a1-hello');
      await viewModel.playMedia('a1-hello');
      await viewModel.startPronunciationRecording();
      await viewModel.stopAndAssessPronunciation(
        expectedText: 'hello',
        locale: 'en',
      );

      expect(viewModel.downloadedMediaIds, contains('a1-hello'));
      expect(platform.played, ['downloaded:a1-hello']);
      expect(platform.recording, isFalse);
      expect(viewModel.pronunciationFeedback?.score, 88);
    },
  );

  test(
    'completes placement, engagement, reminder and entitlement lifecycle',
    () async {
      final gateway = FakeP1Gateway();
      final platform = FakeAdvancedLearningPlatform();
      final viewModel = P1ViewModel(
        gateway,
        platform,
        closedTestingCommerceEnabled: true,
      );
      await viewModel.load();
      for (final question in viewModel.assessment!.questions) {
        viewModel.selectAssessmentAnswer(question.id, question.options.first);
      }

      await viewModel.submitPlacement();
      await viewModel.recordLearningActivity();
      await viewModel.updateReminder(
        enabled: true,
        locale: 'en',
        title: 'Reminder',
        body: 'Practise',
      );
      await viewModel.purchasePremium();
      await viewModel.refundPremium();

      expect(viewModel.placementResult?.hasCompletionRecord, isTrue);
      expect(viewModel.engagement?.xp, 15);
      expect(platform.reminderScheduled, isTrue);
      expect(viewModel.entitlement?.status, 'revoked');
    },
  );

  test(
    'keeps protected actions off when Android permissions are denied',
    () async {
      final gateway = FakeP1Gateway();
      final platform = FakeAdvancedLearningPlatform()
        ..microphoneAllowed = false
        ..notificationAllowed = false;
      final viewModel = P1ViewModel(
        gateway,
        platform,
        closedTestingCommerceEnabled: true,
      );
      await viewModel.load();

      await viewModel.startPronunciationRecording();
      expect(viewModel.recording, isFalse);
      expect(viewModel.permissionIssue, P1PermissionIssue.microphone);

      await viewModel.updateReminder(
        enabled: true,
        locale: 'en',
        title: 'Reminder',
        body: 'Practise',
      );
      expect(viewModel.engagement?.reminderEnabled, isFalse);
      expect(platform.reminderScheduled, isFalse);
      expect(viewModel.permissionIssue, P1PermissionIssue.notifications);
    },
  );
}

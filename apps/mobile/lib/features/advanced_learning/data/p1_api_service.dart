import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import 'p1_models.dart';

abstract interface class P1Gateway {
  Future<List<AdvancedActivityDefinition>> advancedActivities(String courseId);

  Future<AdvancedFeedback> assessPronunciation({
    required String audioBase64,
    required String expectedText,
    required String locale,
  });

  Future<AdvancedFeedback> textFeedback({
    required String kind,
    required String contentRef,
    required String input,
    required String locale,
  });

  Future<PlacementAssessment> getPlacement(String courseId);

  Future<PlacementResult> submitPlacement({
    required String assessmentId,
    required List<String> answers,
  });

  Future<EngagementStatus> getEngagement();

  Future<EngagementStatus> recordActivity({
    required String eventType,
    required String evidenceRef,
  });

  Future<void> updateReminder({
    required bool enabled,
    required String reminderTime,
    required String locale,
    required String timezone,
  });

  Future<Entitlement> verifyClosedTestingPurchase(String productId);

  Future<Entitlement> refundLatestClosedTestingPurchase(String productId);

  Future<SupportTicket> createSupportTicket({
    required String type,
    required String? contentRef,
    required String locale,
    required String description,
  });
}

class P1ApiService implements P1Gateway {
  P1ApiService(this._api, {this.uuid = const Uuid()});

  final ApiClient _api;
  final Uuid uuid;
  String? _closedTestingPurchaseToken;

  @override
  Future<List<AdvancedActivityDefinition>> advancedActivities(
    String courseId,
  ) async {
    final response = await _api.get(
      '/api/mobile/v1/courses/$courseId/advanced-activities',
    );
    return (response['items'] as List<dynamic>)
        .map(
          (item) => AdvancedActivityDefinition.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AdvancedFeedback> assessPronunciation({
    required String audioBase64,
    required String expectedText,
    required String locale,
  }) async => AdvancedFeedback.fromJson(
    await _api.post(
      '/api/mobile/v1/advanced/pronunciation',
      authenticated: true,
      idempotencyKey: uuid.v4(),
      body: {
        'clientRequestId': uuid.v4(),
        'audioBase64': audioBase64,
        'expectedText': expectedText,
        'locale': locale,
      },
    ),
  );

  @override
  Future<AdvancedFeedback> textFeedback({
    required String kind,
    required String contentRef,
    required String input,
    required String locale,
  }) async => AdvancedFeedback.fromJson(
    await _api.post(
      '/api/mobile/v1/advanced/$kind',
      authenticated: true,
      idempotencyKey: uuid.v4(),
      body: {
        'clientRequestId': uuid.v4(),
        'contentRef': contentRef,
        'input': input,
        'locale': locale,
      },
    ),
  );

  @override
  Future<PlacementAssessment> getPlacement(String courseId) async =>
      PlacementAssessment.fromJson(
        await _api.get(
          '/api/mobile/v1/assessments/placement',
          query: {'courseId': courseId},
          authenticated: true,
        ),
      );

  @override
  Future<PlacementResult> submitPlacement({
    required String assessmentId,
    required List<String> answers,
  }) async => PlacementResult.fromJson(
    await _api.post(
      '/api/mobile/v1/assessments/placement/attempts',
      authenticated: true,
      idempotencyKey: uuid.v4(),
      body: {
        'clientAttemptId': uuid.v4(),
        'assessmentId': assessmentId,
        'answers': answers,
      },
    ),
  );

  @override
  Future<EngagementStatus> getEngagement() async => EngagementStatus.fromJson(
    await _api.get('/api/mobile/v1/engagement', authenticated: true),
  );

  @override
  Future<EngagementStatus> recordActivity({
    required String eventType,
    required String evidenceRef,
  }) async => EngagementStatus.fromJson(
    await _api.post(
      '/api/mobile/v1/engagement/activities',
      authenticated: true,
      idempotencyKey: uuid.v4(),
      body: {
        'clientEventId': uuid.v4(),
        'eventType': eventType,
        'evidenceRef': evidenceRef,
      },
    ),
  );

  @override
  Future<void> updateReminder({
    required bool enabled,
    required String reminderTime,
    required String locale,
    required String timezone,
  }) async {
    await _api.put(
      '/api/mobile/v1/engagement/notification-preference',
      authenticated: true,
      idempotencyKey: uuid.v4(),
      body: {
        'enabled': enabled,
        'reminderTime': reminderTime,
        'locale': locale,
        'timezone': timezone,
      },
    );
  }

  @override
  Future<Entitlement> verifyClosedTestingPurchase(String productId) async {
    final token = _closedTestingPurchaseToken ??= 'local-test-${uuid.v4()}';
    return Entitlement.fromJson(
      await _api.post(
        '/api/mobile/v1/commerce/purchases/verify',
        authenticated: true,
        idempotencyKey: uuid.v4(),
        body: {'purchaseToken': token, 'productId': productId},
      ),
    );
  }

  @override
  Future<Entitlement> refundLatestClosedTestingPurchase(
    String productId,
  ) async {
    final token = _closedTestingPurchaseToken;
    if (token == null) {
      throw StateError('No closed-testing purchase is available to refund.');
    }
    return Entitlement.fromJson(
      await _api.post(
        '/api/mobile/v1/commerce/purchases/refund',
        authenticated: true,
        idempotencyKey: uuid.v4(),
        body: {'purchaseToken': token, 'productId': productId},
      ),
    );
  }

  @override
  Future<SupportTicket> createSupportTicket({
    required String type,
    required String? contentRef,
    required String locale,
    required String description,
  }) async => SupportTicket.fromJson(
    await _api.post(
      '/api/mobile/v1/support/tickets',
      authenticated: true,
      body: {
        'type': type,
        if (contentRef != null && contentRef.isNotEmpty)
          'contentRef': contentRef,
        'locale': locale,
        'description': description,
      },
    ),
  );
}

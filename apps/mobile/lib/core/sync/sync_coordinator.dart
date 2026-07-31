import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../network/api_problem.dart';
import '../storage/app_database.dart';

class SyncCoordinator {
  SyncCoordinator(
    this._database,
    this._api, {
    this.uuid = const Uuid(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final ApiClient _api;
  final Uuid uuid;
  final DateTime Function() _now;
  Future<SyncRunResult>? _inFlight;

  Future<void> enqueueAttempt({
    required String clientMutationId,
    required String idempotencyKey,
    required Map<String, dynamic> payload,
    required DateTime occurredAt,
  }) => _database.enqueueMutation(
    LocalMutation(
      clientMutationId: clientMutationId,
      idempotencyKey: idempotencyKey,
      type: 'attempt.submit',
      payload: payload,
      occurredAt: occurredAt,
    ),
  );

  Future<SyncRunResult> synchronize() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _synchronize();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<SyncRunResult> _synchronize() async {
    final pending = await _database.pendingMutations(now: _now());
    final results = <String, Map<String, dynamic>>{};
    var cursor = await _database.syncCursor();

    if (pending.isNotEmpty) {
      final clientBatchId = uuid.v4();
      try {
        final response = await _api.post(
          '/api/mobile/v1/sync/push',
          authenticated: true,
          idempotencyKey: clientBatchId,
          body: {
            'clientBatchId': clientBatchId,
            'baseCursor': ?cursor,
            'mutations': pending
                .map(
                  (mutation) => {
                    'clientMutationId': mutation.clientMutationId,
                    'type': mutation.type,
                    'idempotencyKey': mutation.idempotencyKey,
                    'payload': mutation.payload,
                  },
                )
                .toList(),
          },
        );
        final appliedIds = <String>[];
        for (final item in response['results'] as List<dynamic>) {
          final result = item as Map<String, dynamic>;
          final id = result['clientMutationId'] as String;
          appliedIds.add(id);
          results[id] = result['result'] as Map<String, dynamic>;
        }
        cursor = response['nextCursor'] as String;
        await _database.applySyncResult(
          appliedMutationIds: appliedIds,
          changes: const [],
          nextCursor: cursor,
        );
      } on Object catch (error) {
        await _scheduleRetry(pending, error);
        rethrow;
      }
    }

    cursor = await _pull(cursor);
    return SyncRunResult(results: results, cursor: cursor);
  }

  Future<String?> _pull(String? cursor) async {
    var currentCursor = cursor;
    var hasMore = true;
    while (hasMore) {
      final response = await _api.get(
        '/api/mobile/v1/sync/pull',
        authenticated: true,
        query: {'cursor': ?currentCursor, 'limit': '50'},
      );
      final changes = (response['changes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CanonicalChange.fromJson)
          .toList(growable: false);
      currentCursor = response['nextCursor'] as String;
      hasMore = response['hasMore'] as bool;
      await _database.applySyncResult(
        appliedMutationIds: const [],
        changes: changes,
        nextCursor: currentCursor,
      );
    }
    return currentCursor;
  }

  Future<void> _scheduleRetry(List<LocalMutation> pending, Object error) async {
    final code = error is ApiProblem
        ? error.code
        : error is NetworkUnavailable
        ? 'NETWORK_UNAVAILABLE'
        : 'SYNC_FAILED';
    for (final mutation in pending) {
      final attempt = mutation.attemptCount + 1;
      final exponent = attempt.clamp(1, 6);
      await _database.markMutationFailed(
        mutation.clientMutationId,
        attemptCount: attempt,
        nextAttemptAt: _now().toUtc().add(Duration(seconds: 1 << exponent)),
        errorCode: code,
      );
    }
  }
}

class SyncRunResult {
  const SyncRunResult({required this.results, required this.cursor});

  final Map<String, Map<String, dynamic>> results;
  final String? cursor;
}

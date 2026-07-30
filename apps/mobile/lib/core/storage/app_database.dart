import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory})
    : _factory = factory ?? databaseFactory;

  static const _databaseName = 'esquilospeak_mobile.db';
  static const _schemaVersion = 1;

  final DatabaseFactory _factory;
  Database? _database;

  Future<void> open({String? path}) async {
    if (_database != null) return;
    final resolvedPath = path ?? '${await getDatabasesPath()}/$_databaseName';
    _database = await _factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE pending_mutation (
              client_mutation_id TEXT PRIMARY KEY,
              idempotency_key TEXT NOT NULL,
              mutation_type TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              next_attempt_at TEXT,
              last_error_code TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE canonical_change (
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              occurred_at TEXT NOT NULL,
              PRIMARY KEY (entity_type, entity_id)
            )
          ''');
          await database.execute('''
            CREATE TABLE app_state (
              state_key TEXT PRIMARY KEY,
              state_value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> enqueueMutation(LocalMutation mutation) async {
    await _db.insert(
      'pending_mutation',
      mutation.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<LocalMutation>> pendingMutations({
    int limit = 100,
    DateTime? now,
  }) async {
    final rows = await _db.query(
      'pending_mutation',
      where: 'next_attempt_at IS NULL OR next_attempt_at <= ?',
      whereArgs: [(now ?? DateTime.now()).toUtc().toIso8601String()],
      orderBy: 'occurred_at ASC',
      limit: limit,
    );
    return rows.map(LocalMutation.fromRow).toList(growable: false);
  }

  Future<void> markMutationFailed(
    String clientMutationId, {
    required int attemptCount,
    required DateTime nextAttemptAt,
    required String errorCode,
  }) => _db.update(
    'pending_mutation',
    {
      'attempt_count': attemptCount,
      'next_attempt_at': nextAttemptAt.toUtc().toIso8601String(),
      'last_error_code': errorCode,
    },
    where: 'client_mutation_id = ?',
    whereArgs: [clientMutationId],
  );

  Future<void> applySyncResult({
    required Iterable<String> appliedMutationIds,
    required Iterable<CanonicalChange> changes,
    required String nextCursor,
  }) => _db.transaction((transaction) async {
    for (final id in appliedMutationIds) {
      await transaction.delete(
        'pending_mutation',
        where: 'client_mutation_id = ?',
        whereArgs: [id],
      );
    }
    for (final change in changes) {
      await transaction.insert(
        'canonical_change',
        change.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await transaction.insert('app_state', {
      'state_key': 'sync_cursor',
      'state_value': nextCursor,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<String?> syncCursor() async {
    final rows = await _db.query(
      'app_state',
      columns: ['state_value'],
      where: 'state_key = ?',
      whereArgs: ['sync_cursor'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['state_value'] as String;
  }

  Future<bool> booleanSetting(String key, {bool defaultValue = false}) async {
    final rows = await _db.query(
      'app_state',
      columns: ['state_value'],
      where: 'state_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return rows.single['state_value'] == 'true';
  }

  Future<void> setBooleanSetting(String key, bool value) => _db.insert(
    'app_state',
    {'state_key': key, 'state_value': '$value'},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Database get _db {
    final database = _database;
    if (database == null) throw StateError('AppDatabase is not open.');
    return database;
  }
}

class LocalMutation {
  const LocalMutation({
    required this.clientMutationId,
    required this.idempotencyKey,
    required this.type,
    required this.payload,
    required this.occurredAt,
    this.attemptCount = 0,
  });

  factory LocalMutation.fromRow(Map<String, Object?> row) => LocalMutation(
    clientMutationId: row['client_mutation_id'] as String,
    idempotencyKey: row['idempotency_key'] as String,
    type: row['mutation_type'] as String,
    payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
    occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
    attemptCount: row['attempt_count'] as int,
  );

  final String clientMutationId;
  final String idempotencyKey;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;
  final int attemptCount;

  Map<String, Object?> toRow() => {
    'client_mutation_id': clientMutationId,
    'idempotency_key': idempotencyKey,
    'mutation_type': type,
    'payload_json': jsonEncode(payload),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'attempt_count': attemptCount,
  };
}

class CanonicalChange {
  const CanonicalChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.occurredAt,
  });

  factory CanonicalChange.fromJson(Map<String, dynamic> json) =>
      CanonicalChange(
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        operation: json['operation'] as String,
        payload: json['payload'] as Map<String, dynamic>,
        occurredAt: DateTime.parse(json['occurredAt'] as String).toUtc(),
      );

  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;

  Map<String, Object?> toRow() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'operation': operation,
    'payload_json': jsonEncode(payload),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

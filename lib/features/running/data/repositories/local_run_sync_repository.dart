import 'package:sqflite/sqflite.dart';

import '../services/run_sync_service.dart';

enum RunSyncStatus { pending, failed, synced }

class RunSyncQueueEntry {
  const RunSyncQueueEntry({
    required this.runId,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    this.lastErrorCode,
    this.syncedAt,
  });

  final String runId;
  final RunSyncStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? lastErrorCode;
  final DateTime? syncedAt;

  factory RunSyncQueueEntry.fromRow(Map<String, Object?> row) {
    DateTime? readDate(Object? value) {
      if (value == null) return null;

      return DateTime.fromMicrosecondsSinceEpoch(
        (value as num).toInt(),
        isUtc: true,
      );
    }

    return RunSyncQueueEntry(
      runId: row['run_id'] as String,
      status: RunSyncStatus.values.byName(row['sync_status'] as String),
      attemptCount: (row['attempt_count'] as num).toInt(),
      nextAttemptAt: readDate(row['next_attempt_at_us']),
      lastError: row['last_error'] as String?,
      lastErrorCode: row['last_error_code'] as String?,
      syncedAt: readDate(row['synced_at_us']),
    );
  }
}

class LocalRunSyncRepository {
  LocalRunSyncRepository({
    required Database database,
    DateTime Function()? clock,
  }) : _database = database,
       _clock = clock ?? DateTime.now;

  final Database _database;
  final DateTime Function() _clock;

  void _validateOwner(String ownerUid) {
    if (ownerUid.trim().isEmpty) {
      throw ArgumentError('O UID do proprietário é obrigatório.');
    }
  }

  void _validateIds(String ownerUid, String runId) {
    _validateOwner(ownerUid);

    if (runId.trim().isEmpty) {
      throw ArgumentError('O identificador da corrida é obrigatório.');
    }
  }

  Future<List<RunSyncQueueEntry>> getDueRuns({
    required String ownerUid,
    int limit = 10,
  }) async {
    _validateOwner(ownerUid);

    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Use de 1 a 100.');
    }

    final rows = await _database.query(
      'run_sync_queue',
      where:
          'owner_uid = ? '
          'AND sync_status IN (?, ?) '
          'AND next_attempt_at_us IS NOT NULL '
          'AND next_attempt_at_us <= ?',
      whereArgs: [
        ownerUid,
        RunSyncStatus.pending.name,
        RunSyncStatus.failed.name,
        _clock().microsecondsSinceEpoch,
      ],
      orderBy: 'created_at_us ASC, run_id ASC',
      limit: limit,
    );

    return List<RunSyncQueueEntry>.unmodifiable(
      rows.map(RunSyncQueueEntry.fromRow),
    );
  }

  Future<RunSyncQueueEntry?> getEntry({
    required String ownerUid,
    required String runId,
  }) async {
    _validateIds(ownerUid, runId);

    final rows = await _database.query(
      'run_sync_queue',
      where: 'owner_uid = ? AND run_id = ?',
      whereArgs: [ownerUid, runId],
      limit: 1,
    );

    return rows.isEmpty ? null : RunSyncQueueEntry.fromRow(rows.single);
  }

  Future<bool> recordAttempt({
    required String ownerUid,
    required String runId,
  }) async {
    _validateIds(ownerUid, runId);

    return _database.transaction<bool>((transaction) async {
      final now = _clock();
      final nowUs = now.microsecondsSinceEpoch;

      final rows = await transaction.query(
        'run_sync_queue',
        where:
            'owner_uid = ? AND run_id = ? '
            'AND sync_status IN (?, ?) '
            'AND next_attempt_at_us IS NOT NULL '
            'AND next_attempt_at_us <= ?',
        whereArgs: [
          ownerUid,
          runId,
          RunSyncStatus.pending.name,
          RunSyncStatus.failed.name,
          nowUs,
        ],
        limit: 1,
      );

      if (rows.isEmpty) return false;

      final attempts = (rows.single['attempt_count'] as num).toInt();

      await transaction.update(
        'run_sync_queue',
        {
          'sync_status': RunSyncStatus.pending.name,
          'attempt_count': attempts + 1,
          'last_attempt_at_us': nowUs,
          'updated_at_us': nowUs,
          'last_error': null,
          'last_error_code': null,

          // Se o processo encerrar durante a chamada, a tentativa
          // poderá ser recuperada depois dessa espera.
          'next_attempt_at_us': now
              .add(const Duration(seconds: 60))
              .microsecondsSinceEpoch,
        },
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, runId],
      );

      return true;
    });
  }

  Future<void> recordFailure({
    required String ownerUid,
    required String runId,
    required String errorCode,
    required String message,
    required bool retryable,
  }) async {
    _validateIds(ownerUid, runId);

    await _database.transaction<void>((transaction) async {
      final rows = await transaction.query(
        'run_sync_queue',
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, runId],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final entry = RunSyncQueueEntry.fromRow(rows.single);

      if (entry.status == RunSyncStatus.synced) return;

      if (entry.attemptCount < 1) {
        throw StateError('Registre a tentativa antes de registrar a falha.');
      }

      final now = _clock();

      // 30s, 60s, 120s... com limite de 30 minutos.
      final exponent = (entry.attemptCount - 1).clamp(0, 6).toInt();
      final seconds = (30 * (1 << exponent)).clamp(30, 1800).toInt();

      final nextAttempt = retryable
          ? now.add(Duration(seconds: seconds)).microsecondsSinceEpoch
          : null;

      await transaction.update(
        'run_sync_queue',
        {
          'sync_status': RunSyncStatus.failed.name,
          'last_error_code': errorCode,
          'last_error': message,
          'next_attempt_at_us': nextAttempt,
          'updated_at_us': now.microsecondsSinceEpoch,
        },
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, runId],
      );
    });
  }

  Future<bool> markSynced({
    required String ownerUid,
    required RunSyncReceipt receipt,
  }) async {
    _validateIds(ownerUid, receipt.runId);

    if (!receipt.distanceMeters.isFinite ||
        receipt.distanceMeters < 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(receipt.contentHash)) {
      throw StateError('Confirmação de sincronização inválida.');
    }

    return _database.transaction<bool>((transaction) async {
      final rows = await transaction.rawQuery(
        '''
        SELECT
          q.*,
          s.status AS run_status,
          s.point_count AS local_point_count,
          s.active_duration_us AS local_duration_us
        FROM run_sync_queue q
        JOIN run_sessions s
          ON s.owner_uid = q.owner_uid
          AND s.run_id = q.run_id
        WHERE q.owner_uid = ? AND q.run_id = ?
        LIMIT 1
        ''',
        [ownerUid, receipt.runId],
      );

      // A corrida pode ter sido excluída durante o envio.
      if (rows.isEmpty) return false;

      final row = rows.single;

      final durationMs = (row['local_duration_us'] as num).toInt() ~/ 1000;

      if (row['run_status'] != 'finished' ||
          (row['local_point_count'] as num).toInt() != receipt.pointCount ||
          durationMs != receipt.activeDuration.inMilliseconds) {
        throw StateError('A confirmação não corresponde à corrida local.');
      }

      if (row['sync_status'] == RunSyncStatus.synced.name) {
        if (row['content_hash'] != receipt.contentHash) {
          throw StateError('A corrida já possui outra confirmação.');
        }

        return true;
      }

      if ((row['attempt_count'] as num).toInt() < 1) {
        throw StateError('Não existe tentativa registrada para esta corrida.');
      }

      final nowUs = _clock().microsecondsSinceEpoch;

      await transaction.update(
        'run_sync_queue',
        {
          'sync_status': RunSyncStatus.synced.name,
          'synced_at_us': nowUs,
          'content_hash': receipt.contentHash,
          'server_distance_meters': receipt.distanceMeters,
          'next_attempt_at_us': null,
          'last_error': null,
          'last_error_code': null,
          'updated_at_us': nowUs,
        },
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, receipt.runId],
      );

      return true;
    });
  }

  Future<bool> retryNow({
    required String ownerUid,
    required String runId,
  }) async {
    _validateIds(ownerUid, runId);

    final changed = await _database.update(
      'run_sync_queue',
      {
        'sync_status': RunSyncStatus.pending.name,
        'next_attempt_at_us': _clock().microsecondsSinceEpoch,
        'last_error': null,
        'last_error_code': null,
        'updated_at_us': _clock().microsecondsSinceEpoch,
      },
      where: 'owner_uid = ? AND run_id = ? AND sync_status = ?',
      whereArgs: [ownerUid, runId, RunSyncStatus.failed.name],
    );

    return changed == 1;
  }
}

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/run_point.dart';
import '../../domain/entities/run_session.dart';
import '../../domain/repositories/runs_repository.dart';

class LocalRunsRepository implements RunsRepository {
  LocalRunsRepository({required Database database}) : _database = database;

  final Database _database;

  @override
  Future<void> saveSession({
    required String ownerUid,
    required RunSession session,
  }) async {
    _validateIds(ownerUid, session.id);
    _validateSession(session);

    await _database.transaction<void>((transaction) async {
      final existingRows = await transaction.query(
        'run_sessions',
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, session.id],
        limit: 1,
      );

      final existing = existingRows.isEmpty ? null : existingRows.first;
      final storedCount = existing == null
          ? 0
          : (existing['point_count'] as num).toInt();

      if (existing != null) {
        if ((existing['started_at_us'] as num).toInt() !=
            session.startedAt.microsecondsSinceEpoch) {
          throw StateError('A data inicial da corrida não pode mudar.');
        }

        if (existing['status'] == RunStatus.finished.name) {
          // Uma corrida finalizada não pode ser sobrescrita
          // por uma gravação atrasada do controlador.
          final unchanged =
              session.status == RunStatus.finished &&
              storedCount == session.points.length &&
              (existing['active_duration_us'] as num).toInt() ==
                  session.activeDuration.inMicroseconds &&
              (existing['distance_meters'] as num).toDouble() ==
                  session.distanceMeters &&
              (existing['ended_at_us'] as num).toInt() ==
                  session.endedAt!.microsecondsSinceEpoch;

          if (!unchanged) {
            throw StateError('A corrida já foi finalizada no banco.');
          }

          return;
        }

        if (session.points.length < storedCount ||
            session.activeDuration.inMicroseconds <
                (existing['active_duration_us'] as num).toInt() ||
            session.distanceMeters <
                (existing['distance_meters'] as num).toDouble()) {
          throw StateError('Foi recebida uma versão antiga da corrida.');
        }
      }

      final summary = <String, Object?>{
        'owner_uid': ownerUid,
        'run_id': session.id,
        'started_at_us': session.startedAt.microsecondsSinceEpoch,
        'ended_at_us': session.endedAt?.microsecondsSinceEpoch,
        'status': session.status.name,
        'active_duration_us': session.activeDuration.inMicroseconds,
        'distance_meters': session.distanceMeters,
        'point_count': session.points.length,
        'updated_at_us': DateTime.now().microsecondsSinceEpoch,
      };

      if (existing == null) {
        await transaction.insert('run_sessions', summary);
      } else {
        await transaction.update(
          'run_sessions',
          summary,
          where: 'owner_uid = ? AND run_id = ?',
          whereArgs: [ownerUid, session.id],
        );
      }

      // Os pontos são imutáveis e acrescentados ao fim da sessão.
      // Grava somente os que ainda não estão no banco.
      if (storedCount < session.points.length) {
        final batch = transaction.batch();

        for (var index = storedCount; index < session.points.length; index++) {
          final point = session.points[index];

          batch.insert('run_points', {
            'owner_uid': ownerUid,
            'run_id': session.id,
            'sequence': index,
            'segment_index': point.segmentIndex,
            'latitude': point.latitude,
            'longitude': point.longitude,
            'recorded_at_us': point.recordedAt.microsecondsSinceEpoch,
            'accuracy_meters': point.accuracyMeters,
          });
        }

        await batch.commit(noResult: true);
      }
    });
  }

  Future<RunSession?> getSession({
    required String ownerUid,
    required String runId,
  }) async {
    _validateIds(ownerUid, runId);

    return _database.transaction<RunSession?>((transaction) async {
      final rows = await transaction.query(
        'run_sessions',
        where: 'owner_uid = ? AND run_id = ?',
        whereArgs: [ownerUid, runId],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return _readSession(transaction, rows.single);
    });
  }

  @override
  Future<RunSession?> getRecoverableSession({required String ownerUid}) async {
    _validateOwner(ownerUid);

    return _database.transaction<RunSession?>((transaction) async {
      final rows = await transaction.query(
        'run_sessions',
        where: 'owner_uid = ? AND status IN (?, ?)',
        whereArgs: [ownerUid, RunStatus.recording.name, RunStatus.paused.name],
        orderBy: 'updated_at_us DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final session = await _readSession(transaction, rows.first);

      if (session.status == RunStatus.recording) {
        await transaction.update(
          'run_sessions',
          {
            'status': RunStatus.paused.name,
            'updated_at_us': DateTime.now().microsecondsSinceEpoch,
          },
          where: 'owner_uid = ? AND run_id = ?',
          whereArgs: [ownerUid, session.id],
        );
      }

      // Não acrescenta tempo nem coordenadas após a interrupção.
      return session.copyWith(status: RunStatus.paused);
    });
  }

  @override
  Future<List<RunSession>> getFinishedSessions({
    required String ownerUid,
    int limit = 30,
    int offset = 0,
  }) async {
    _validateOwner(ownerUid);

    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Use de 1 a 100.');
    }

    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Use zero ou mais.');
    }

    return _database.transaction<List<RunSession>>((transaction) async {
      final rows = await transaction.query(
        'run_sessions',
        where: 'owner_uid = ? AND status = ?',
        whereArgs: [ownerUid, RunStatus.finished.name],
        orderBy: 'started_at_us DESC, run_id ASC',
        limit: limit,
        offset: offset,
      );

      final sessions = <RunSession>[];

      for (final row in rows) {
        sessions.add(await _readSession(transaction, row));
      }

      return List<RunSession>.unmodifiable(sessions);
    });
  }

  @override
  Future<void> deleteSession({
    required String ownerUid,
    required String runId,
  }) async {
    _validateIds(ownerUid, runId);

    await _database.delete(
      'run_sessions',
      where: 'owner_uid = ? AND run_id = ?',
      whereArgs: [ownerUid, runId],
    );
  }

  Future<RunSession> _readSession(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final pointRows = await executor.query(
      'run_points',
      where: 'owner_uid = ? AND run_id = ?',
      whereArgs: [row['owner_uid'], row['run_id']],
      orderBy: 'sequence ASC',
    );

    final expectedCount = (row['point_count'] as num).toInt();

    if (pointRows.length != expectedCount) {
      throw const FormatException(
        'A quantidade de pontos não corresponde ao resumo da corrida.',
      );
    }

    final points = <RunPoint>[];

    for (var index = 0; index < pointRows.length; index++) {
      final pointRow = pointRows[index];

      if ((pointRow['sequence'] as num).toInt() != index) {
        throw const FormatException('A sequência do percurso está incompleta.');
      }

      points.add(
        RunPoint(
          latitude: (pointRow['latitude'] as num).toDouble(),
          longitude: (pointRow['longitude'] as num).toDouble(),
          recordedAt: _dateFromValue(pointRow['recorded_at_us']),
          accuracyMeters: (pointRow['accuracy_meters'] as num).toDouble(),
          segmentIndex: (pointRow['segment_index'] as num).toInt(),
        ),
      );
    }

    final endedAt = row['ended_at_us'];

    final session = RunSession(
      id: row['run_id'] as String,
      startedAt: _dateFromValue(row['started_at_us']),
      endedAt: endedAt == null ? null : _dateFromValue(endedAt),
      status: RunStatus.values.byName(row['status'] as String),
      activeDuration: Duration(
        microseconds: (row['active_duration_us'] as num).toInt(),
      ),
      distanceMeters: (row['distance_meters'] as num).toDouble(),
      points: points,
    );

    _validateSession(session);
    return session;
  }

  DateTime _dateFromValue(Object? value) {
    return DateTime.fromMicrosecondsSinceEpoch(
      (value as num).toInt(),
      isUtc: true,
    );
  }

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

  void _validateSession(RunSession session) {
    if (!session.distanceMeters.isFinite ||
        session.distanceMeters < 0 ||
        session.activeDuration < Duration.zero) {
      throw ArgumentError('As métricas da corrida são inválidas.');
    }

    if (session.status == RunStatus.finished) {
      if (session.endedAt == null ||
          session.endedAt!.isBefore(session.startedAt)) {
        throw ArgumentError('A data de finalização é inválida.');
      }
    } else if (session.endedAt != null) {
      throw ArgumentError('Uma corrida ativa não pode ter data de término.');
    }

    RunPoint? previous;

    for (final point in session.points) {
      if (!point.hasValidCoordinates ||
          !point.hasValidAccuracy ||
          point.segmentIndex < 0) {
        throw ArgumentError('O percurso contém um ponto inválido.');
      }

      if (previous != null &&
          (!point.recordedAt.isAfter(previous.recordedAt) ||
              point.segmentIndex < previous.segmentIndex)) {
        throw ArgumentError('A ordem dos pontos ou segmentos é inválida.');
      }

      previous = point;
    }
  }
}

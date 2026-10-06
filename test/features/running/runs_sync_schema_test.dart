import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:okan_app/features/running/data/database/runs_local_database.dart';
import 'package:okan_app/features/running/data/repositories/local_runs_repository.dart';
import 'package:okan_app/features/running/domain/entities/run_point.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';

Future<Database> openTestDatabase(
  String databasePath, {
  int version = RunsLocalDatabase.schemaVersion,
}) {
  return databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: RunsLocalDatabase.createSchema,
      onUpgrade: RunsLocalDatabase.upgradeSchema,
    ),
  );
}

RunSession sampleRun({
  String id = 'run-1',
  RunStatus status = RunStatus.finished,
}) {
  final startedAt = DateTime.utc(2026, 10, 5, 12);

  return RunSession(
    id: id,
    startedAt: startedAt,
    endedAt: status == RunStatus.finished
        ? startedAt.add(const Duration(minutes: 1))
        : null,
    status: status,
    activeDuration: const Duration(seconds: 10),
    distanceMeters: 6,
    points: [
      RunPoint(
        latitude: -22.785,
        longitude: -43.311,
        recordedAt: startedAt,
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
      RunPoint(
        latitude: -22.78495,
        longitude: -43.311,
        recordedAt: startedAt.add(const Duration(seconds: 5)),
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
    ],
  );
}

void main() {
  sqfliteFfiInit();

  late Database database;
  late LocalRunsRepository repository;

  setUp(() async {
    database = await openTestDatabase(inMemoryDatabasePath);
    repository = LocalRunsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('somente finalização coloca corrida na fila, sem duplicar', () async {
    await repository.saveSession(
      ownerUid: 'owner-a',
      session: sampleRun(status: RunStatus.recording),
    );

    expect(await database.query('run_sync_queue'), isEmpty);

    final finished = sampleRun();

    await repository.saveSession(ownerUid: 'owner-a', session: finished);

    await repository.saveSession(ownerUid: 'owner-a', session: finished);

    final queue = await database.query('run_sync_queue');

    expect(queue, hasLength(1));
    expect(queue.single['sync_status'], 'pending');
    expect(queue.single['attempt_count'], 0);
    expect(queue.single['run_id'], finished.id);
  });

  test('falha nos pontos reverte sessão e pendência', () async {
    await database.execute('''
      CREATE TRIGGER simulate_sync_point_failure
      BEFORE INSERT ON run_points
      WHEN NEW.sequence = 1
      BEGIN
        SELECT RAISE(ABORT, 'Falha simulada');
      END
    ''');

    await expectLater(
      repository.saveSession(ownerUid: 'owner-a', session: sampleRun()),
      throwsA(isA<DatabaseException>()),
    );

    expect(await database.query('run_sessions'), isEmpty);
    expect(await database.query('run_points'), isEmpty);
    expect(await database.query('run_sync_queue'), isEmpty);
  });

  test('separa contas e exclusão local respeita o proprietário', () async {
    final session = sampleRun();

    await repository.saveSession(ownerUid: 'owner-a', session: session);

    await repository.saveSession(ownerUid: 'owner-b', session: session);

    expect(await database.query('run_sync_queue'), hasLength(2));

    await repository.deleteSession(ownerUid: 'owner-a', runId: session.id);

    final queue = await database.query('run_sync_queue');

    expect(queue, hasLength(1));
    expect(queue.single['owner_uid'], 'owner-b');
  });

  test('repetir salvamento não reinicia uma pendência sincronizada', () async {
    final session = sampleRun();

    await repository.saveSession(ownerUid: 'owner-a', session: session);

    await database.update(
      'run_sync_queue',
      {
        'sync_status': 'synced',
        'synced_at_us': DateTime.now().microsecondsSinceEpoch,
        'content_hash': List.filled(64, 'a').join(),
        'server_distance_meters': 6.0,
        'attempt_count': 1,
      },
      where: 'owner_uid = ? AND run_id = ?',
      whereArgs: ['owner-a', session.id],
    );

    await repository.saveSession(ownerUid: 'owner-a', session: session);

    final queue = await database.query('run_sync_queue');

    expect(queue, hasLength(1));
    expect(queue.single['sync_status'], 'synced');
    expect(queue.single['attempt_count'], 1);
  });

  test('migração v1 preserva corridas e enfileira só finalizadas', () async {
    final directory = await Directory.systemTemp.createTemp(
      'okan-running-migration-',
    );

    final databasePath = path.join(directory.path, 'migration.db');

    try {
      final legacy = await openTestDatabase(databasePath, version: 1);

      try {
        final legacyRepository = LocalRunsRepository(database: legacy);

        await legacyRepository.saveSession(
          ownerUid: 'owner-a',
          session: sampleRun(id: 'finished-old'),
        );

        await legacyRepository.saveSession(
          ownerUid: 'owner-a',
          session: sampleRun(id: 'active-old', status: RunStatus.recording),
        );
      } finally {
        await legacy.close();
      }

      final upgraded = await openTestDatabase(databasePath);

      try {
        final upgradedRepository = LocalRunsRepository(database: upgraded);

        final history = await upgradedRepository.getFinishedSessions(
          ownerUid: 'owner-a',
        );

        expect(history, hasLength(1));
        expect(history.single.id, 'finished-old');
        expect(history.single.points, hasLength(2));
        expect(history.single.distanceMeters, 6);
        expect(history.single.activeDuration, const Duration(seconds: 10));

        final sessions = await upgraded.query('run_sessions');
        expect(sessions, hasLength(2));

        final active = sessions.singleWhere(
          (row) => row['run_id'] == 'active-old',
        );
        expect(active['status'], 'recording');

        final queue = await upgraded.query('run_sync_queue');

        expect(queue, hasLength(1));
        expect(queue.single['run_id'], 'finished-old');
        expect(queue.single['sync_status'], 'pending');

        expect(await upgraded.getVersion(), 2);
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

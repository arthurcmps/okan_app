import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:okan_app/features/running/data/database/runs_local_database.dart';
import 'package:okan_app/features/running/data/repositories/local_run_sync_repository.dart';
import 'package:okan_app/features/running/data/repositories/local_runs_repository.dart';
import 'package:okan_app/features/running/data/services/run_sync_service.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';
import 'package:okan_app/features/running/presentation/controllers/run_sync_controller.dart';

RunSession finishedSyncRun() {
  final start = DateTime.utc(2026, 10, 5, 12);

  return RunSession(
    id: 'run-1',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 1)),
    status: RunStatus.finished,
    activeDuration: const Duration(minutes: 1),
  );
}

Map<String, dynamic> syncResponse() {
  return {
    'runId': 'run-1',
    'alreadySynced': false,
    'distanceMeters': 0,
    'activeDurationMs': 60000,
    'pointCount': 0,
    'contentHash': List.filled(64, 'a').join(),
  };
}

void main() {
  sqfliteFfiInit();

  late Database database;
  late LocalRunsRepository runs;
  late LocalRunSyncRepository queue;
  late DateTime now;
  late String? currentUid;

  RunSyncController createController(RunUploadInvoker invoke) {
    return RunSyncController(
      ownerUid: 'owner-a',
      runsRepository: runs,
      queueRepository: queue,
      currentUserId: () => currentUid,
      syncService: RunSyncService(
        currentUserId: () => currentUid,
        invokeUpload: invoke,
      ),
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 5, 13);
    currentUid = 'owner-a';

    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: RunsLocalDatabase.schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: RunsLocalDatabase.createSchema,
        onUpgrade: RunsLocalDatabase.upgradeSchema,
      ),
    );

    runs = LocalRunsRepository(database: database);

    queue = LocalRunSyncRepository(database: database, clock: () => now);

    await runs.saveSession(ownerUid: 'owner-a', session: finishedSyncRun());
  });

  tearDown(() async {
    await database.close();
  });

  test('envia pendência e registra confirmação', () async {
    var calls = 0;

    final controller = createController((payload) async {
      calls++;
      expect(payload['runId'], 'run-1');
      return syncResponse();
    });

    try {
      await controller.syncPending();

      final entry = await controller.getState('run-1');

      expect(calls, 1);
      expect(entry!.status, RunSyncStatus.synced);
      expect(entry.attemptCount, 1);
      expect(controller.isSyncing, isFalse);
    } finally {
      controller.dispose();
    }
  });

  test('falha temporária preserva corrida e permite reenvio', () async {
    var calls = 0;

    final controller = createController((_) async {
      calls++;

      if (calls == 1) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Falha simulada.',
        );
      }

      return syncResponse();
    });

    try {
      await controller.syncPending();

      final failed = await controller.getState('run-1');

      expect(failed!.status, RunSyncStatus.failed);

      expect(
        await runs.getSession(ownerUid: 'owner-a', runId: 'run-1'),
        isNotNull,
      );

      await controller.syncPending();
      expect(calls, 1);

      now = now.add(const Duration(seconds: 30));

      await controller.syncPending();

      final synced = await controller.getState('run-1');

      expect(calls, 2);
      expect(synced!.status, RunSyncStatus.synced);
      expect(synced.attemptCount, 2);
    } finally {
      controller.dispose();
    }
  });

  test('outra conta não processa a fila', () async {
    var calls = 0;
    currentUid = 'owner-b';

    final controller = createController((_) async {
      calls++;
      return syncResponse();
    });

    try {
      await controller.syncPending();

      final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

      expect(calls, 0);
      expect(entry!.attemptCount, 0);
      expect(entry.status, RunSyncStatus.pending);
    } finally {
      controller.dispose();
    }
  });

  test('troca de conta durante envio não confirma a fila', () async {
    final controller = createController((_) async {
      currentUid = 'owner-b';
      return syncResponse();
    });

    try {
      await controller.syncPending();

      final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

      expect(entry!.status, RunSyncStatus.pending);
      expect(entry.syncedAt, isNull);
      expect(entry.attemptCount, 1);
    } finally {
      controller.dispose();
    }
  });

  test('chamadas simultâneas compartilham o mesmo envio', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;

    final controller = createController((_) async {
      calls++;
      started.complete();
      await release.future;
      return syncResponse();
    });

    try {
      final first = controller.syncPending();

      await started.future;

      final second = controller.syncPending();

      expect(controller.isSyncing, isTrue);

      release.complete();

      await Future.wait([first, second]);

      expect(calls, 1);

      final entry = await controller.getState('run-1');
      expect(entry!.status, RunSyncStatus.synced);
    } finally {
      controller.dispose();
    }
  });

  test('descarte durante envio deixa a tentativa recuperável', () async {
    final started = Completer<void>();
    final release = Completer<void>();

    final controller = createController((_) async {
      started.complete();
      await release.future;
      return syncResponse();
    });

    final sending = controller.syncPending();

    await started.future;

    controller.dispose();
    release.complete();

    await sending;

    final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

    expect(entry!.status, RunSyncStatus.pending);
    expect(entry.syncedAt, isNull);

    now = now.add(const Duration(seconds: 60));

    expect(await queue.getDueRuns(ownerUid: 'owner-a'), hasLength(1));
  });
}

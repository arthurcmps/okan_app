import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:okan_app/features/running/data/database/runs_local_database.dart';
import 'package:okan_app/features/running/data/repositories/local_runs_repository.dart';
import 'package:okan_app/features/running/data/repositories/local_run_sync_repository.dart';
import 'package:okan_app/features/running/data/services/run_sync_service.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';

Future<Database> openSyncTestDatabase(String databasePath) {
  return databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: RunsLocalDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: RunsLocalDatabase.createSchema,
      onUpgrade: RunsLocalDatabase.upgradeSchema,
    ),
  );
}

RunSession finishedRun() {
  final start = DateTime.utc(2026, 10, 5, 12);

  return RunSession(
    id: 'run-1',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 1)),
    status: RunStatus.finished,
    activeDuration: const Duration(minutes: 1),
  );
}

RunSyncReceipt receipt({int pointCount = 0}) {
  return RunSyncReceipt(
    runId: 'run-1',
    alreadySynced: false,
    distanceMeters: 0,
    activeDuration: const Duration(minutes: 1),
    pointCount: pointCount,
    contentHash: List.filled(64, 'a').join(),
  );
}

void main() {
  sqfliteFfiInit();

  late Database database;
  late LocalRunsRepository runs;
  late LocalRunSyncRepository queue;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 10, 5, 13);

    database = await openSyncTestDatabase(inMemoryDatabasePath);
    runs = LocalRunsRepository(database: database);

    queue = LocalRunSyncRepository(database: database, clock: () => now);

    await runs.saveSession(ownerUid: 'owner-a', session: finishedRun());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'consulta somente a conta e impede tentativa repetida imediata',
    () async {
      expect(await queue.getDueRuns(ownerUid: 'owner-b'), isEmpty);
      expect(await queue.getDueRuns(ownerUid: 'owner-a'), hasLength(1));

      expect(
        await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1'),
        isTrue,
      );

      expect(
        await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1'),
        isFalse,
      );

      expect(await queue.getDueRuns(ownerUid: 'owner-a'), isEmpty);

      final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

      expect(entry!.attemptCount, 1);
    },
  );

  test(
    'falha temporária espera antes de reenviar e aumenta intervalo',
    () async {
      await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

      await queue.recordFailure(
        ownerUid: 'owner-a',
        runId: 'run-1',
        errorCode: 'unavailable',
        message: 'Sem conexão.',
        retryable: true,
      );

      expect(await queue.getDueRuns(ownerUid: 'owner-a'), isEmpty);

      now = now.add(const Duration(seconds: 30));

      expect(await queue.getDueRuns(ownerUid: 'owner-a'), hasLength(1));

      await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

      await queue.recordFailure(
        ownerUid: 'owner-a',
        runId: 'run-1',
        errorCode: 'unavailable',
        message: 'Sem conexão.',
        retryable: true,
      );

      final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

      expect(entry!.attemptCount, 2);
      expect(entry.nextAttemptAt, now.add(const Duration(seconds: 60)));
    },
  );

  test('falha permanente depende de tentativa manual', () async {
    await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

    await queue.recordFailure(
      ownerUid: 'owner-a',
      runId: 'run-1',
      errorCode: 'invalid-argument',
      message: 'Dados inválidos.',
      retryable: false,
    );

    now = now.add(const Duration(days: 1));

    expect(await queue.getDueRuns(ownerUid: 'owner-a'), isEmpty);

    expect(await queue.retryNow(ownerUid: 'owner-b', runId: 'run-1'), isFalse);

    expect(await queue.retryNow(ownerUid: 'owner-a', runId: 'run-1'), isTrue);

    expect(await queue.getDueRuns(ownerUid: 'owner-a'), hasLength(1));
  });

  test(
    'confirmação incompatível não marca corrida como sincronizada',
    () async {
      await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

      await expectLater(
        queue.markSynced(ownerUid: 'owner-a', receipt: receipt(pointCount: 10)),
        throwsStateError,
      );

      final entry = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

      expect(entry!.status, RunSyncStatus.pending);
      expect(entry.syncedAt, isNull);
    },
  );

  test('confirmação respeita a conta e pode ser repetida', () async {
    await queue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

    expect(
      await queue.markSynced(ownerUid: 'owner-b', receipt: receipt()),
      isFalse,
    );

    expect(
      await queue.markSynced(ownerUid: 'owner-a', receipt: receipt()),
      isTrue,
    );

    final first = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

    now = now.add(const Duration(minutes: 1));

    expect(
      await queue.markSynced(ownerUid: 'owner-a', receipt: receipt()),
      isTrue,
    );

    final repeated = await queue.getEntry(ownerUid: 'owner-a', runId: 'run-1');

    expect(repeated!.status, RunSyncStatus.synced);
    expect(repeated.syncedAt, first!.syncedAt);
    expect(await queue.getDueRuns(ownerUid: 'owner-a'), isEmpty);

    expect(await queue.retryNow(ownerUid: 'owner-a', runId: 'run-1'), isFalse);
  });

  test('falha e próxima tentativa sobrevivem à reabertura do banco', () async {
    final directory = await Directory.systemTemp.createTemp(
      'okan-sync-persistence-',
    );

    final databasePath = path.join(directory.path, 'sync.db');

    try {
      final firstDb = await openSyncTestDatabase(databasePath);

      try {
        await LocalRunsRepository(
          database: firstDb,
        ).saveSession(ownerUid: 'owner-a', session: finishedRun());

        final firstQueue = LocalRunSyncRepository(
          database: firstDb,
          clock: () => now,
        );

        await firstQueue.recordAttempt(ownerUid: 'owner-a', runId: 'run-1');

        await firstQueue.recordFailure(
          ownerUid: 'owner-a',
          runId: 'run-1',
          errorCode: 'unavailable',
          message: 'Sem conexão.',
          retryable: true,
        );
      } finally {
        await firstDb.close();
      }

      final reopened = await openSyncTestDatabase(databasePath);

      try {
        final reopenedQueue = LocalRunSyncRepository(
          database: reopened,
          clock: () => now,
        );

        final entry = await reopenedQueue.getEntry(
          ownerUid: 'owner-a',
          runId: 'run-1',
        );

        expect(entry!.status, RunSyncStatus.failed);
        expect(entry.attemptCount, 1);
        expect(entry.lastErrorCode, 'unavailable');
        expect(entry.nextAttemptAt, now.add(const Duration(seconds: 30)));

        expect(await reopenedQueue.getDueRuns(ownerUid: 'owner-a'), isEmpty);

        now = now.add(const Duration(seconds: 30));

        expect(
          await reopenedQueue.getDueRuns(ownerUid: 'owner-a'),
          hasLength(1),
        );
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

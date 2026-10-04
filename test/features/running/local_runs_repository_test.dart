import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:okan_app/features/running/data/database/runs_local_database.dart';
import 'package:okan_app/features/running/data/repositories/local_runs_repository.dart';
import 'package:okan_app/features/running/domain/entities/run_point.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';

RunSession sampleSession({
  String id = 'run-1',
  int pointCount = 2,
  RunStatus status = RunStatus.recording,
}) {
  final startedAt = DateTime.utc(2026, 10, 4, 10);

  return RunSession(
    id: id,
    startedAt: startedAt,
    endedAt: status == RunStatus.finished
        ? startedAt.add(const Duration(minutes: 2))
        : null,
    status: status,
    activeDuration: Duration(seconds: pointCount * 5),
    distanceMeters: (pointCount - 1) * 6.0,
    points: List.generate(
      pointCount,
      (index) => RunPoint(
        latitude: -22.785 + index * 0.00005,
        longitude: -43.311,
        recordedAt: startedAt.add(Duration(seconds: index * 5)),
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
    ),
  );
}

void main() {
  sqfliteFfiInit();

  late Database database;
  late LocalRunsRepository repository;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: RunsLocalDatabase.createSchema,
      ),
    );

    repository = LocalRunsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('recupera corrida como pausada sem acrescentar tempo', () async {
    final original = sampleSession();

    await repository.saveSession(ownerUid: 'student-a', session: original);

    final recovered = await repository.getRecoverableSession(
      ownerUid: 'student-a',
    );

    expect(recovered, isNotNull);
    expect(recovered!.id, original.id);
    expect(recovered.status, RunStatus.paused);
    expect(recovered.activeDuration, original.activeDuration);
    expect(recovered.distanceMeters, original.distanceMeters);
    expect(recovered.endedAt, isNull);
    expect(recovered.points.length, original.points.length);
    expect(recovered.points.first.recordedAt, original.points.first.recordedAt);
    expect(recovered.points.last.latitude, original.points.last.latitude);

    final rows = await database.query('run_sessions');
    expect(rows.single['status'], 'paused');
  });

  test('gravação repetida não duplica pontos e aceita novos pontos', () async {
    final original = sampleSession();

    await repository.saveSession(ownerUid: 'student-a', session: original);

    await repository.saveSession(ownerUid: 'student-a', session: original);

    expect((await database.query('run_points')).length, 2);

    final updated = sampleSession(pointCount: 3);

    await repository.saveSession(ownerUid: 'student-a', session: updated);

    expect((await database.query('run_points')).length, 3);

    final recovered = await repository.getRecoverableSession(
      ownerUid: 'student-a',
    );

    expect(recovered!.points.length, 3);
    expect(recovered.distanceMeters, updated.distanceMeters);
    expect(recovered.activeDuration, updated.activeDuration);
  });

  test('separa usuários e exclusão remove somente seus pontos', () async {
    final session = sampleSession();

    await repository.saveSession(ownerUid: 'student-a', session: session);

    expect(
      await repository.getRecoverableSession(ownerUid: 'student-b'),
      isNull,
    );

    // Outro usuário não consegue excluir pelo mesmo runId.
    await repository.deleteSession(ownerUid: 'student-b', runId: session.id);

    expect((await database.query('run_points')).length, 2);

    // O mesmo runId pode existir em outra conta.
    await repository.saveSession(ownerUid: 'student-b', session: session);

    await repository.deleteSession(ownerUid: 'student-a', runId: session.id);

    expect(
      await repository.getRecoverableSession(ownerUid: 'student-a'),
      isNull,
    );

    final otherUser = await repository.getRecoverableSession(
      ownerUid: 'student-b',
    );

    expect(otherUser, isNotNull);
    expect(otherUser!.points.length, 2);

    final remainingPoints = await database.query('run_points');
    expect(remainingPoints.length, 2);
    expect(
      remainingPoints.every((row) => row['owner_uid'] == 'student-b'),
      isTrue,
    );
  });

  test(
    'finalização aparece no histórico e rejeita gravação atrasada',
    () async {
      final original = sampleSession();
      final finished = sampleSession(status: RunStatus.finished);

      await repository.saveSession(ownerUid: 'student-a', session: original);

      await repository.saveSession(ownerUid: 'student-a', session: finished);

      // Repetir a finalização é permitido.
      await repository.saveSession(ownerUid: 'student-a', session: finished);

      expect(
        await repository.getRecoverableSession(ownerUid: 'student-a'),
        isNull,
      );

      final history = await repository.getFinishedSessions(
        ownerUid: 'student-a',
      );

      expect(history.length, 1);
      expect(history.single.status, RunStatus.finished);
      expect(history.single.endedAt, finished.endedAt);
      expect(history.single.points.length, 2);

      expect(
        await repository.getFinishedSessions(ownerUid: 'student-b'),
        isEmpty,
      );

      await expectLater(
        repository.saveSession(ownerUid: 'student-a', session: original),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('impede duas corridas ativas na mesma conta', () async {
    await repository.saveSession(
      ownerUid: 'student-a',
      session: sampleSession(id: 'run-1'),
    );

    await expectLater(
      repository.saveSession(
        ownerUid: 'student-a',
        session: sampleSession(id: 'run-2'),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect((await database.query('run_sessions')).length, 1);
    expect((await database.query('run_points')).length, 2);
  });

  test('falha ao inserir pontos reverte também o resumo', () async {
    // Provoca uma falha real dentro da transação.
    await database.execute('''
      CREATE TRIGGER simulate_point_failure
      BEFORE INSERT ON run_points
      WHEN NEW.sequence = 1
      BEGIN
        SELECT RAISE(ABORT, 'Falha simulada ao gravar ponto');
      END
    ''');

    await expectLater(
      repository.saveSession(ownerUid: 'student-a', session: sampleSession()),
      throwsA(isA<DatabaseException>()),
    );

    expect(await database.query('run_sessions'), isEmpty);
    expect(await database.query('run_points'), isEmpty);
  });

  test('rejeita versão antiga sem perder os pontos mais recentes', () async {
    final updated = sampleSession(pointCount: 3);

    await repository.saveSession(ownerUid: 'student-a', session: updated);

    await expectLater(
      repository.saveSession(
        ownerUid: 'student-a',
        session: sampleSession(pointCount: 2),
      ),
      throwsA(isA<StateError>()),
    );

    final recovered = await repository.getRecoverableSession(
      ownerUid: 'student-a',
    );

    expect(recovered!.points.length, 3);
    expect(recovered.distanceMeters, updated.distanceMeters);
  });
}

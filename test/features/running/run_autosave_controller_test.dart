import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/running/domain/entities/run_point.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';
import 'package:okan_app/features/running/domain/repositories/runs_repository.dart';
import 'package:okan_app/features/running/presentation/controllers/run_autosave_controller.dart';
import 'package:okan_app/features/running/presentation/controllers/running_controller.dart';

class FakeRunsRepository implements RunsRepository {
  final savedSessions = <RunSession>[];
  final savedOwners = <String>[];

  Future<void> Function(RunSession session)? beforeSave;

  bool failNextSave = false;
  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<void> saveSession({
    required String ownerUid,
    required RunSession session,
  }) async {
    activeWrites++;

    if (activeWrites > maxConcurrentWrites) {
      maxConcurrentWrites = activeWrites;
    }

    try {
      final callback = beforeSave;
      if (callback != null) {
        await callback(session);
      }

      if (failNextSave) {
        failNextSave = false;
        throw StateError('Falha simulada no armazenamento.');
      }

      savedOwners.add(ownerUid);
      savedSessions.add(session);
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<RunSession?> getRecoverableSession({required String ownerUid}) async =>
      null;

  @override
  Future<List<RunSession>> getFinishedSessions({
    required String ownerUid,
    int limit = 30,
    int offset = 0,
  }) async => [];

  @override
  Future<void> deleteSession({
    required String ownerUid,
    required String runId,
  }) async {}
}

RunSession recoveredSession() {
  final startedAt = DateTime.now().subtract(const Duration(minutes: 10));

  return RunSession(
    id: 'autosave-run',
    startedAt: startedAt,
    status: RunStatus.paused,
    activeDuration: const Duration(minutes: 2),
    distanceMeters: 200,
    points: [
      RunPoint(
        latitude: -22.785,
        longitude: -43.311,
        recordedAt: startedAt,
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
    ],
  );
}

Future<void> deliverEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late RunningController running;
  late FakeRunsRepository repository;
  RunAutosaveController? autosave;

  setUp(() {
    repository = FakeRunsRepository();
    running = RunningController();
    running.restorePausedSession(recoveredSession());
    autosave = null;
  });

  tearDown(() {
    autosave?.dispose();
    running.dispose();
  });

  RunAutosaveController createAutosave() {
    final controller = RunAutosaveController(
      runningController: running,
      repository: repository,
      ownerUid: 'student-a',
    );

    autosave = controller;
    return controller;
  }

  test('salva a sessão com seu proprietário e confirma a gravação', () async {
    final saver = createAutosave();

    expect(await saver.flush(), isTrue);

    expect(repository.savedSessions.length, 1);
    expect(repository.savedOwners.single, 'student-a');
    expect(
      repository.savedSessions.single.activeDuration,
      const Duration(minutes: 2),
    );
    expect(saver.lastSavedAt, isNotNull);
    expect(saver.errorMessage, isNull);
    expect(saver.hasPendingChanges, isFalse);
  });

  test('serializa gravações e preserva finalização pendente', () async {
    final gate = Completer<void>();
    var attempt = 0;

    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    repository.beforeSave = (session) async {
      attempt++;

      if (attempt == 1) {
        await gate.future;
      }
    };

    final saver = createAutosave();

    await deliverEvents();
    expect(repository.activeWrites, 1);

    // Finaliza enquanto a primeira versão ainda está sendo gravada.
    await running.finish();

    final completion = saver.flush();

    gate.complete();

    expect(await completion, isTrue);
    expect(repository.maxConcurrentWrites, 1);
    expect(repository.savedSessions.length, 2);
    expect(repository.savedSessions.first.status, RunStatus.paused);
    expect(repository.savedSessions.last.status, RunStatus.finished);
    expect(saver.hasPendingChanges, isFalse);
  });

  test('mantém dados após falha e retry salva a versão mais recente', () async {
    repository.failNextSave = true;

    final saver = createAutosave();

    expect(await saver.flush(), isFalse);
    expect(saver.errorMessage, isNotNull);
    expect(saver.hasPendingChanges, isTrue);
    expect(repository.savedSessions, isEmpty);

    // A versão finalizada deve substituir a versão pendente anterior.
    await running.finish();

    expect(await saver.retry(), isTrue);

    expect(repository.savedSessions.length, 1);
    expect(repository.savedSessions.single.status, RunStatus.finished);
    expect(repository.savedSessions.single.points.length, 1);
    expect(saver.errorMessage, isNull);
    expect(saver.hasPendingChanges, isFalse);
  });

  test(
    'flush repetido não duplica gravações nem bloqueia as futuras',
    () async {
      final saver = createAutosave();

      final results = await Future.wait([
        saver.flush(),
        saver.flush(),
        saver.flush(),
      ]);

      expect(results, everyElement(isTrue));
      expect(repository.savedSessions.length, 1);

      expect(await saver.flush(), isTrue);
      expect(repository.savedSessions.length, 1);

      await running.finish();

      expect(await saver.flush(), isTrue);
      expect(repository.savedSessions.length, 2);
      expect(repository.savedSessions.last.status, RunStatus.finished);
    },
  );
}

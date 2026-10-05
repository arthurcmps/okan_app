import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/running/data/services/run_sync_service.dart';
import 'package:okan_app/features/running/domain/entities/run_point.dart';
import 'package:okan_app/features/running/domain/entities/run_session.dart';

RunSession finishedSession() {
  final startedAt = DateTime.utc(2026, 10, 5, 12);

  return RunSession(
    id: 'run-1',
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 1)),
    status: RunStatus.finished,
    activeDuration: const Duration(minutes: 1),
    distanceMeters: 111,
    points: [
      RunPoint(
        latitude: 0,
        longitude: 0,
        recordedAt: startedAt,
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
      RunPoint(
        latitude: 0,
        longitude: 0.001,
        recordedAt: startedAt.add(const Duration(seconds: 20)),
        accuracyMeters: 5,
        segmentIndex: 0,
      ),
    ],
  );
}

Map<String, dynamic> validResponse({bool alreadySynced = false}) {
  return {
    'runId': 'run-1',
    'alreadySynced': alreadySynced,
    'distanceMeters': 111.195,
    'activeDurationMs': 60000,
    'pointCount': 2,
    'contentHash': List.filled(64, 'a').join(),
  };
}

void main() {
  test('serializa datas e duração em milissegundos', () {
    final session = finishedSession();
    final payload = buildRunUploadPayload(session);

    expect(payload['startedAtMs'], session.startedAt.millisecondsSinceEpoch);
    expect(payload['endedAtMs'], session.endedAt!.millisecondsSinceEpoch);
    expect(payload['activeDurationMs'], 60000);
    expect(payload['reportedDistanceMeters'], 111);
    expect(payload['points'], hasLength(2));
    expect(payload.containsKey('ownerUid'), isFalse);
  });

  test('recusa corrida ainda não finalizada', () {
    final session = RunSession(
      id: 'run-open',
      startedAt: DateTime.utc(2026, 10, 5),
      status: RunStatus.paused,
    );

    expect(() => buildRunUploadPayload(session), throwsStateError);
  });

  test('envia a corrida e aceita a confirmação do backend', () async {
    Map<String, dynamic>? sentPayload;

    final service = RunSyncService(
      currentUserId: () => 'owner-a',
      invokeUpload: (payload) async {
        sentPayload = payload;
        return validResponse();
      },
    );

    final receipt = await service.syncFinishedSession(
      ownerUid: 'owner-a',
      session: finishedSession(),
    );

    expect(sentPayload!['runId'], 'run-1');
    expect(receipt.runId, 'run-1');
    expect(receipt.alreadySynced, isFalse);
    expect(receipt.distanceMeters, 111.195);
  });

  test('outra conta não pode enviar a corrida local', () async {
    var called = false;

    final service = RunSyncService(
      currentUserId: () => 'owner-b',
      invokeUpload: (_) async {
        called = true;
        return validResponse();
      },
    );

    await expectLater(
      service.syncFinishedSession(
        ownerUid: 'owner-a',
        session: finishedSession(),
      ),
      throwsStateError,
    );

    expect(called, isFalse);
  });

  test('descarta confirmação se a conta mudar durante o envio', () async {
    String? currentUid = 'owner-a';

    final service = RunSyncService(
      currentUserId: () => currentUid,
      invokeUpload: (_) async {
        currentUid = 'owner-b';
        return validResponse();
      },
    );

    await expectLater(
      service.syncFinishedSession(
        ownerUid: 'owner-a',
        session: finishedSession(),
      ),
      throwsStateError,
    );
  });

  test('recusa confirmação de outra corrida ou com dados incompletos', () {
    final session = finishedSession();

    for (final response in [
      {...validResponse(), 'runId': 'other-run'},
      {...validResponse(), 'pointCount': 999},
      {...validResponse(), 'activeDurationMs': 999},
      {...validResponse(), 'contentHash': ''},
      {...validResponse(), 'distanceMeters': -1},
    ]) {
      expect(
        () => RunSyncReceipt.fromResponse(response, session: session),
        throwsStateError,
      );
    }
  });

  test('aceita confirmação de um reenvio já sincronizado', () async {
    final service = RunSyncService(
      currentUserId: () => 'owner-a',
      invokeUpload: (_) async => validResponse(alreadySynced: true),
    );

    final receipt = await service.syncFinishedSession(
      ownerUid: 'owner-a',
      session: finishedSession(),
    );

    expect(receipt.alreadySynced, isTrue);
    expect(receipt.runId, 'run-1');
  });
}

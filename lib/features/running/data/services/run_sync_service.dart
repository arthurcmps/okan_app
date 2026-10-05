import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/run_session.dart';

typedef RunUploadInvoker =
    Future<Object?> Function(Map<String, dynamic> payload);

Map<String, dynamic> buildRunUploadPayload(RunSession session) {
  final endedAt = session.endedAt;

  if (session.status != RunStatus.finished || endedAt == null) {
    throw StateError('Somente corridas finalizadas podem ser sincronizadas.');
  }

  if (session.id.isEmpty ||
      endedAt.isBefore(session.startedAt) ||
      session.activeDuration.isNegative ||
      !session.distanceMeters.isFinite ||
      session.distanceMeters < 0) {
    throw StateError('A corrida possui dados inválidos.');
  }

  if (session.points.length > 20000) {
    throw StateError('O percurso excede o limite desta versão.');
  }

  final points = <Map<String, dynamic>>[];

  for (final point in session.points) {
    if (!point.hasValidCoordinates ||
        !point.hasValidAccuracy ||
        point.segmentIndex < 0) {
      throw StateError('O percurso possui um ponto inválido.');
    }

    points.add({
      'latitude': point.latitude,
      'longitude': point.longitude,
      'recordedAtMs': point.recordedAt.millisecondsSinceEpoch,
      'accuracyMeters': point.accuracyMeters,
      'segmentIndex': point.segmentIndex,
    });
  }

  return {
    'schemaVersion': 1,
    'runId': session.id,
    'status': 'finished',
    'startedAtMs': session.startedAt.millisecondsSinceEpoch,
    'endedAtMs': endedAt.millisecondsSinceEpoch,
    'activeDurationMs': session.activeDuration.inMilliseconds,
    'reportedDistanceMeters': session.distanceMeters,
    'points': points,
  };
}

class RunSyncReceipt {
  const RunSyncReceipt({
    required this.runId,
    required this.alreadySynced,
    required this.distanceMeters,
    required this.activeDuration,
    required this.pointCount,
    required this.contentHash,
  });

  final String runId;
  final bool alreadySynced;
  final double distanceMeters;
  final Duration activeDuration;
  final int pointCount;
  final String contentHash;

  factory RunSyncReceipt.fromResponse(
    Object? response, {
    required RunSession session,
  }) {
    if (response is! Map) {
      throw StateError('Confirmação de sincronização inválida.');
    }

    final runId = response['runId'];
    final alreadySynced = response['alreadySynced'];
    final distance = response['distanceMeters'];
    final contentHash = response['contentHash'];

    if (runId != session.id ||
        alreadySynced is! bool ||
        distance is! num ||
        !distance.isFinite ||
        distance < 0 ||
        response['activeDurationMs'] != session.activeDuration.inMilliseconds ||
        response['pointCount'] != session.points.length ||
        contentHash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(contentHash)) {
      throw StateError('Confirmação de sincronização inválida.');
    }

    return RunSyncReceipt(
      runId: session.id,
      alreadySynced: alreadySynced,
      distanceMeters: distance.toDouble(),
      activeDuration: session.activeDuration,
      pointCount: session.points.length,
      contentHash: contentHash,
    );
  }
}

class RunSyncService {
  RunSyncService({
    FirebaseFunctions? functions,
    String? Function()? currentUserId,
    RunUploadInvoker? invokeUpload,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _invokeUpload =
           invokeUpload ??
           ((payload) async {
             final client =
                 functions ??
                 FirebaseFunctions.instanceFor(region: 'southamerica-east1');

             final callable = client.httpsCallable(
               'syncFinishedRun',
               options: HttpsCallableOptions(
                 timeout: const Duration(seconds: 60),
               ),
             );

             final result = await callable.call(payload);
             return result.data;
           });

  final String? Function() _currentUserId;
  final RunUploadInvoker _invokeUpload;

  Future<RunSyncReceipt> syncFinishedSession({
    required String ownerUid,
    required RunSession session,
  }) async {
    if (ownerUid.isEmpty || _currentUserId() != ownerUid) {
      throw StateError(
        'Entre na conta proprietária para sincronizar esta corrida.',
      );
    }

    final payload = buildRunUploadPayload(session);
    final response = await _invokeUpload(payload);

    // Uma troca de conta durante a chamada impede que a fila
    // da sessão atual utilize essa confirmação.
    if (_currentUserId() != ownerUid) {
      throw StateError('A conta mudou durante a sincronização.');
    }

    return RunSyncReceipt.fromResponse(response, session: session);
  }
}

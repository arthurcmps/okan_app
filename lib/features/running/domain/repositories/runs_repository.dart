import '../entities/run_session.dart';

abstract interface class RunsRepository {
  Future<void> saveSession({
    required String ownerUid,
    required RunSession session,
  });

  Future<RunSession?> getRecoverableSession({required String ownerUid});

  Future<List<RunSession>> getFinishedSessions({
    required String ownerUid,
    int limit = 30,
    int offset = 0,
  });

  Future<void> deleteSession({required String ownerUid, required String runId});
}

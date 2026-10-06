import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/local_run_sync_repository.dart';
import '../../data/repositories/local_runs_repository.dart';
import '../../data/services/run_sync_service.dart';

class RunSyncController extends ChangeNotifier {
  RunSyncController({
    required this.ownerUid,
    required LocalRunsRepository runsRepository,
    required LocalRunSyncRepository queueRepository,
    required RunSyncService syncService,
    String? Function()? currentUserId,
    this.retryInterval = const Duration(seconds: 30),
  }) : _runsRepository = runsRepository,
       _queueRepository = queueRepository,
       _syncService = syncService,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid) {
    if (ownerUid.trim().isEmpty) {
      throw ArgumentError('O UID do proprietário é obrigatório.');
    }

    if (retryInterval <= Duration.zero) {
      throw ArgumentError('O intervalo de sincronização deve ser positivo.');
    }
  }

  final String ownerUid;
  final Duration retryInterval;

  final LocalRunsRepository _runsRepository;
  final LocalRunSyncRepository _queueRepository;
  final RunSyncService _syncService;
  final String? Function() _currentUserId;

  Timer? _retryTimer;
  Future<void>? _inFlight;

  bool _disposed = false;
  bool _rescanRequested = false;
  String? _errorMessage;

  bool get isSyncing => _inFlight != null;
  String? get errorMessage => _errorMessage;

  bool get _canWork => !_disposed && _currentUserId() == ownerUid;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    if (_disposed || _retryTimer != null) return;

    _retryTimer = Timer.periodic(
      retryInterval,
      (_) => unawaited(syncPending()),
    );

    unawaited(syncPending());
  }

  Future<void> syncPending() {
    if (!_canWork) return Future<void>.value();

    final existing = _inFlight;

    if (existing != null) {
      _rescanRequested = true;
      return existing;
    }

    // Agenda o trabalho depois de registrar a chamada em andamento.
    // Assim, chamadas simultâneas compartilham a mesma execução.
    final task = Future<void>.microtask(_drain).whenComplete(() {
      _inFlight = null;
      _notify();
    });

    _inFlight = task;
    _notify();

    return task;
  }

  Future<void> _drain() async {
    _errorMessage = null;

    try {
      // Limita cada execução. O timer buscará os próximos lotes.
      // Uma segunda passagem atende pedidos feitos durante o envio.
      for (var pass = 0; pass < 2; pass++) {
        if (!_canWork) return;

        _rescanRequested = false;

        final entries = await _queueRepository.getDueRuns(
          ownerUid: ownerUid,
          limit: 10,
        );

        for (final entry in entries) {
          if (!_canWork) return;
          await _syncEntry(entry);
        }

        if (!_rescanRequested) break;
      }
    } catch (error) {
      if (_canWork) {
        _errorMessage =
            'Não foi possível consultar ou atualizar a fila de sincronização.';

        debugPrint('Erro na fila de corridas: ${error.runtimeType}');
      }
    }
  }

  Future<void> _syncEntry(RunSyncQueueEntry entry) async {
    if (!_canWork) return;

    final registered = await _queueRepository.recordAttempt(
      ownerUid: ownerUid,
      runId: entry.runId,
    );

    if (!registered || !_canWork) return;

    try {
      final session = await _runsRepository.getSession(
        ownerUid: ownerUid,
        runId: entry.runId,
      );

      if (!_canWork || session == null) return;

      final receipt = await _syncService.syncFinishedSession(
        ownerUid: ownerUid,
        session: session,
      );

      if (!_canWork) return;

      await _queueRepository.markSynced(ownerUid: ownerUid, receipt: receipt);
    } catch (error) {
      // Deixa a tentativa recuperável se a conta mudou
      // ou se o controlador foi descartado durante a chamada.
      if (!_canWork) return;

      final failure = _describeFailure(error);

      await _queueRepository.recordFailure(
        ownerUid: ownerUid,
        runId: entry.runId,
        errorCode: failure.$1,
        message: failure.$3,
        retryable: failure.$2,
      );

      _errorMessage = failure.$3;
    }

    _notify();
  }

  (String, bool, String) _describeFailure(Object error) {
    if (error is FirebaseFunctionsException) {
      const temporaryCodes = {
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
        'cancelled',
        'aborted',
      };

      final retryable = temporaryCodes.contains(error.code);

      return (
        error.code,
        retryable,
        retryable
            ? 'A corrida está salva no aparelho. Tentaremos sincronizar novamente.'
            : 'A corrida está salva no aparelho, mas o servidor recusou o envio '
                  '(${error.code}).',
      );
    }

    if (error is TimeoutException) {
      return (
        'deadline-exceeded',
        true,
        'O envio demorou demais. A corrida continua salva no aparelho.',
      );
    }

    if (error is StateError || error is FormatException) {
      return (
        'invalid-local-data',
        false,
        'Não foi possível confirmar os dados desta corrida. '
            'O registro local foi preservado.',
      );
    }

    return (
      'unknown',
      true,
      'Não foi possível sincronizar agora. A corrida continua salva no aparelho.',
    );
  }

  Future<RunSyncQueueEntry?> getState(String runId) {
    return _queueRepository.getEntry(ownerUid: ownerUid, runId: runId);
  }

  Future<void> retryRun(String runId) async {
    if (!_canWork) return;

    final changed = await _queueRepository.retryNow(
      ownerUid: ownerUid,
      runId: runId,
    );

    if (changed && _canWork) {
      await syncPending();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }
}

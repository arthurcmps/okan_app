import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/run_session.dart';
import '../../domain/repositories/runs_repository.dart';
import 'running_controller.dart';

class RunAutosaveController extends ChangeNotifier {
  RunAutosaveController({
    required RunningController runningController,
    required RunsRepository repository,
    required String ownerUid,
  }) : _runningController = runningController,
       _repository = repository,
       _ownerUid = ownerUid {
    if (ownerUid.trim().isEmpty) {
      throw ArgumentError('O UID do proprietário é obrigatório.');
    }

    _runningController.addListener(_onRunChanged);

    _checkpointTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_runningController.isRecording) {
        _queueCurrentSession();
      }
    });

    _onRunChanged();
  }

  final RunningController _runningController;
  final RunsRepository _repository;
  final String _ownerUid;

  Timer? _checkpointTimer;
  Future<void>? _drainFuture;

  RunSession? _pendingSession;
  RunSession? _lastSavedSession;

  String? _observedRunId;
  RunStatus? _observedStatus;
  int? _observedPointCount;

  bool _isSaving = false;
  bool _disposed = false;
  String? _errorMessage;
  DateTime? _lastSavedAt;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSavedAt => _lastSavedAt;

  bool get hasPendingChanges {
    if (_isSaving || _pendingSession != null) return true;

    final current = _runningController.session;
    if (current == null) return false;

    final saved = _lastSavedSession;
    if (saved == null) return true;

    return !_sameContent(current, saved) ||
        current.activeDuration > saved.activeDuration;
  }

  void _onRunChanged() {
    if (_disposed) return;

    final session = _runningController.session;
    if (session == null) return;

    final changed =
        session.id != _observedRunId ||
        session.status != _observedStatus ||
        session.points.length != _observedPointCount;

    _observedRunId = session.id;
    _observedStatus = session.status;
    _observedPointCount = session.points.length;

    if (changed) {
      _queueCurrentSession();
    }
  }

  RunSession? _currentSnapshot() {
    final session = _runningController.session;
    if (session == null) return null;

    return session.copyWith(activeDuration: _runningController.activeDuration);
  }

  void _queueCurrentSession() {
    if (_disposed) return;

    final snapshot = _currentSnapshot();
    if (snapshot == null) return;

    if (_sameSnapshot(snapshot, _lastSavedSession) && _pendingSession == null) {
      return;
    }

    _pendingSession = snapshot;

    if (_errorMessage == null) {
      unawaited(_ensureDrain());
    }

    _emit();
  }

  Future<void> _ensureDrain() {
    final existing = _drainFuture;
    if (existing != null) return existing;

    if (_pendingSession == null || _errorMessage != null) {
      return Future<void>.value();
    }

    // Agenda o processamento depois de registrar a tarefa na fila.
    // Isso também funciona quando não há nada novo para gravar.
    final operation = Future<void>.microtask(_drain);
    _drainFuture = operation;

    return operation;
  }

  Future<void> _drain() async {
    _isSaving = true;
    _emit();

    try {
      while (_pendingSession != null && _errorMessage == null) {
        final snapshot = _pendingSession!;
        _pendingSession = null;

        if (_sameSnapshot(snapshot, _lastSavedSession)) {
          continue;
        }

        try {
          await _repository.saveSession(ownerUid: _ownerUid, session: snapshot);

          _lastSavedSession = snapshot;
          _lastSavedAt = DateTime.now();
        } catch (_) {
          // Preserva a versão mais recente disponível.
          _pendingSession ??= snapshot;

          _errorMessage =
              'Não foi possível salvar a corrida no aparelho. '
              'Os dados pendentes continuam em memória.';

          break;
        }

        _emit();
      }
    } finally {
      _isSaving = false;
      _drainFuture = null;
      _emit();
    }
  }

  Future<bool> flush() async {
    if (_disposed) return false;

    _queueCurrentSession();
    await _ensureDrain();

    // Confirma as versões solicitadas nesta gravação.
    // Enquanto a corrida está ativa, o cronômetro continua avançando.
    return _errorMessage == null && _pendingSession == null && !_isSaving;
  }

  Future<bool> retry() async {
    if (_disposed) return false;

    _errorMessage = null;
    _queueCurrentSession();
    _emit();

    await _ensureDrain();

    return _errorMessage == null && _pendingSession == null && !_isSaving;
  }

  bool _sameContent(RunSession first, RunSession second) {
    return first.id == second.id &&
        first.status == second.status &&
        first.points.length == second.points.length &&
        first.distanceMeters == second.distanceMeters &&
        first.endedAt == second.endedAt;
  }

  bool _sameSnapshot(RunSession first, RunSession? second) {
    return second != null &&
        _sameContent(first, second) &&
        first.activeDuration == second.activeDuration;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _checkpointTimer?.cancel();
    _runningController.removeListener(_onRunChanged);

    // Gravações já solicitadas podem terminar sem atualizar a UI.
    super.dispose();
  }
}

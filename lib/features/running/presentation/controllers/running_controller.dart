import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/location_tracking_service.dart';
import '../../domain/entities/run_point.dart';
import '../../domain/entities/run_session.dart';

class RunningController extends ChangeNotifier {
  RunningController({LocationTrackingService? locationService})
    : _locationService = locationService ?? const LocationTrackingService();

  // Valores iniciais para testes; precisam de calibração em campo.
  static const double _maxAccuracyMeters = 30;
  static const double _minMovementMeters = 3;
  static const double _maxSpeedMetersPerSecond = 12;
  static const Duration _maxPointGap = Duration(seconds: 30);

  final LocationTrackingService _locationService;
  final Stopwatch _stopwatch = Stopwatch();

  Duration _restoredDuration = Duration.zero;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _refreshTimer;

  RunSession? _session;
  Position? _lastPosition;
  RunPoint? _previousPoint;

  bool _isBusy = false;
  bool _disposed = false;
  int _trackingGeneration = 0;
  int _segmentIndex = 0;
  String? _message;

  RunSession? get session => _session;
  Position? get lastPosition => _lastPosition;
  bool get isBusy => _isBusy;
  String? get message => _message;

  Duration get activeDuration =>
      _session == null ? Duration.zero : _restoredDuration + _stopwatch.elapsed;

  bool get isRecording => _session?.status == RunStatus.recording;
  bool get isPaused => _session?.status == RunStatus.paused;
  bool get isFinished => _session?.status == RunStatus.finished;

  void restorePausedSession(RunSession recovered) {
    if (_disposed) return;

    if (_isBusy || _session != null) {
      throw StateError(
        'Só é possível recuperar uma corrida antes de iniciar outra.',
      );
    }

    if (recovered.status != RunStatus.paused) {
      throw ArgumentError('A sessão recuperada precisa estar pausada.');
    }

    _stopwatch.stop();
    _stopwatch.reset();

    _restoredDuration = recovered.activeDuration;
    _session = recovered;
    _previousPoint = null;
    _lastPosition = null;

    _segmentIndex = recovered.points.isEmpty
        ? 0
        : recovered.points.last.segmentIndex;

    _message = 'Corrida recuperada. Retome quando estiver pronto.';
    _emit();
  }

  Future<void> start() async {
    if (_disposed || _isBusy || _session != null) return;

    await _activate(resuming: false);
  }

  Future<void> resume() async {
    if (_disposed || _isBusy || !isPaused) return;

    await _activate(resuming: true);
  }

  Future<void> _activate({required bool resuming}) async {
    _isBusy = true;
    _message = null;
    _emit();

    try {
      final position = await _locationService.getCurrentPosition();
      if (_disposed) return;

      final firstPoint = _pointFromPosition(
        position,
        resuming ? _segmentIndex + 1 : 0,
      );

      if (!firstPoint.hasValidCoordinates ||
          !firstPoint.hasValidAccuracy ||
          firstPoint.accuracyMeters > _maxAccuracyMeters) {
        throw const LocationAccessException(
          'O GPS ainda está com baixa precisão. '
          'Tente novamente em um local aberto.',
        );
      }

      final age = DateTime.now().difference(firstPoint.recordedAt);

      if (age > const Duration(seconds: 20) ||
          age < const Duration(seconds: -5)) {
        throw const LocationAccessException(
          'A posição recebida não é recente. Tente novamente.',
        );
      }

      if (resuming) {
        _segmentIndex++;

        _session = _session!.copyWith(
          status: RunStatus.recording,
          points: [..._session!.points, firstPoint],
        );
      } else {
        _segmentIndex = 0;
        _restoredDuration = Duration.zero;
        _stopwatch.reset();

        _session = RunSession(
          id: const Uuid().v4(),
          startedAt: DateTime.now(),
          status: RunStatus.recording,
          points: [firstPoint],
        );
      }

      _lastPosition = position;
      _previousPoint = firstPoint;
      _stopwatch.start();

      final generation = ++_trackingGeneration;

      _positionSubscription = _locationService.watchPositions().listen(
        (position) {
          if (_disposed || generation != _trackingGeneration) return;

          _handlePosition(position);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_disposed || generation != _trackingGeneration) return;

          unawaited(
            _stopActivity(
              RunStatus.paused,
              message:
                  'A captura de localização falhou. '
                  'A corrida foi pausada; confira o GPS e retome.',
            ),
          );
        },
        onDone: () {
          if (_disposed || generation != _trackingGeneration) return;

          unawaited(
            _stopActivity(
              RunStatus.paused,
              message:
                  'A captura de localização foi encerrada. '
                  'A corrida foi pausada.',
            ),
          );
        },
        cancelOnError: true,
      );

      _refreshTimer?.cancel();

      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed || !isRecording) return;

        _session = _session!.copyWith(activeDuration: activeDuration);

        _emit();
      });
    } on LocationAccessException catch (error) {
      _message = error.message;
      await _recoverFromActivationFailure();
    } on TimeoutException {
      _message = 'O GPS demorou para responder. Tente novamente.';
      await _recoverFromActivationFailure();
    } catch (_) {
      _message = 'Não foi possível iniciar a captura de localização.';
      await _recoverFromActivationFailure();
    } finally {
      _isBusy = false;
      _emit();
    }
  }

  Future<void> _recoverFromActivationFailure() async {
    if (_disposed) return;

    _stopwatch.stop();
    _refreshTimer?.cancel();
    _previousPoint = null;

    if (isRecording) {
      _session = _session!.copyWith(
        status: RunStatus.paused,
        activeDuration: activeDuration,
      );
    }

    await _cancelTracking();
  }

  RunPoint _pointFromPosition(Position position, int segmentIndex) {
    return RunPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp,
      accuracyMeters: position.accuracy,
      segmentIndex: segmentIndex,
    );
  }

  void _handlePosition(Position position) {
    if (!isRecording) return;

    var point = _pointFromPosition(position, _segmentIndex);

    if (!point.hasValidCoordinates || !point.hasValidAccuracy) return;

    _lastPosition = position;

    if (point.accuracyMeters > _maxAccuracyMeters) {
      _message = 'GPS com baixa precisão. Aguardando uma posição melhor.';
      _emit();
      return;
    }

    final previous = _previousPoint;
    double additionalDistance = 0;

    if (previous != null) {
      final interval = point.recordedAt.difference(previous.recordedAt);

      // Descarta posições repetidas ou recebidas fora de ordem.
      if (interval <= Duration.zero) return;

      if (interval > _maxPointGap) {
        // Após uma lacuna, começa outro trecho sem ligar os pontos.
        _segmentIndex++;
        point = _pointFromPosition(position, _segmentIndex);
      } else {
        final distance = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          point.latitude,
          point.longitude,
        );

        final seconds = interval.inMilliseconds / 1000;

        if (!distance.isFinite ||
            seconds <= 0 ||
            distance / seconds > _maxSpeedMetersPerSecond) {
          _message = 'Foi ignorado um salto inesperado do GPS.';
          _emit();
          return;
        }

        // Reduz pequenas oscilações quando o aparelho está parado.
        if (distance < _minMovementMeters) return;

        additionalDistance = distance;
      }
    }

    _previousPoint = point;
    _message = null;

    _session = _session!.copyWith(
      activeDuration: activeDuration,
      distanceMeters: _session!.distanceMeters + additionalDistance,
      points: [..._session!.points, point],
    );

    _emit();
  }

  Future<void> pause() async {
    if (_disposed || _isBusy || !isRecording) return;

    await _stopActivity(RunStatus.paused);
  }

  Future<void> finish() async {
    if (_disposed || _isBusy || (!isRecording && !isPaused)) return;

    await _stopActivity(RunStatus.finished);
  }

  Future<void> _stopActivity(RunStatus status, {String? message}) async {
    if (_disposed || (!isRecording && !isPaused)) return;

    _isBusy = true;
    _stopwatch.stop();
    _refreshTimer?.cancel();
    _previousPoint = null;
    _message = message;

    _session = _session!.copyWith(
      status: status,
      activeDuration: activeDuration,
      endedAt: status == RunStatus.finished ? DateTime.now() : null,
    );

    _emit();

    try {
      await _cancelTracking();
    } finally {
      _isBusy = false;
      _emit();
    }
  }

  Future<void> _cancelTracking() async {
    _trackingGeneration++;

    final subscription = _positionSubscription;
    _positionSubscription = null;

    try {
      await subscription?.cancel();
    } catch (_) {
      _message = 'Não foi possível confirmar o encerramento do GPS.';
    }
  }

  // A página só chamará após confirmação explícita do usuário.
  void clearFinishedSession() {
    if (_disposed || _isBusy || !isFinished) return;

    _session = null;
    _previousPoint = null;
    _message = null;
    _segmentIndex = 0;
    _restoredDuration = Duration.zero;
    _stopwatch.reset();

    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopwatch.stop();
    _refreshTimer?.cancel();

    unawaited(_cancelTracking());

    super.dispose();
  }
}

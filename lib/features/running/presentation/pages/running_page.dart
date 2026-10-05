import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/local_run_sync_repository.dart';
import '../../data/services/run_sync_service.dart';
import '../controllers/run_sync_controller.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/database/runs_local_database.dart';
import '../../data/repositories/local_runs_repository.dart';
import '../../data/services/location_tracking_service.dart';
import '../../domain/entities/run_session.dart';
import '../controllers/run_autosave_controller.dart';
import '../controllers/running_controller.dart';
import 'running_history_page.dart';
import '../../data/services/running_notification_permission_service.dart';

class RunningPage extends StatefulWidget {
  const RunningPage({super.key});

  @override
  State<RunningPage> createState() => _RunningPageState();
}

class _RunningPageState extends State<RunningPage> with WidgetsBindingObserver {
  static const _initialCenter = LatLng(-22.785, -43.311);

  final MapController _mapController = MapController();
  final RunningController _runningController = RunningController();
  final LocationTrackingService _locationService =
      const LocationTrackingService();
  final RunningNotificationPermissionService _notificationPermissionService =
      RunningNotificationPermissionService();

  RunAutosaveController? _autosave;
  StreamSubscription<User?>? _authSubscription;

  String? _ownerUid;
  String? _initializationError;

  LatLng? _locatedPosition;
  double? _locatedAccuracy;
  LocalRunsRepository? _repository;
  RunSyncController? _runSync;
  RunSyncQueueEntry? _syncEntry;
  String? _syncStateError;
  int _syncStateRequest = 0;

  bool _storageReady = false;
  bool _isInitializing = false;
  bool _isLocating = false;
  bool _actionInProgress = false;
  bool _mapReady = false;

  bool get _supportsBackgroundTracking =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isOwner =>
      _ownerUid != null && FirebaseAuth.instance.currentUser?.uid == _ownerUid;

  bool get _isBusy =>
      !_storageReady ||
      !_isOwner ||
      _isLocating ||
      _actionInProgress ||
      _runningController.isBusy;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeStorage());
  }

  Future<void> _initializeStorage() async {
    if (_isInitializing || _storageReady) return;

    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('É necessário entrar no aplicativo.');
      }

      final ownerUid = user.uid;
      final config = OkanEnvironmentConfig.current;

      final environment = switch (config.environment) {
        OkanEnvironment.development => 'dev',
        OkanEnvironment.staging => 'staging',
        OkanEnvironment.production => 'prod',
      };

      final database = await RunsLocalDatabase(environment: environment).open();

      if (!mounted) return;

      final repository = LocalRunsRepository(database: database);

      final recovered = await repository.getRecoverableSession(
        ownerUid: ownerUid,
      );

      if (!mounted) return;

      if (FirebaseAuth.instance.currentUser?.uid != ownerUid) {
        throw StateError('A conta mudou durante a inicialização.');
      }

      _ownerUid = ownerUid;
      _repository = repository;

      if (recovered != null) {
        _runningController.restorePausedSession(recovered);
      }

      _autosave = RunAutosaveController(
        runningController: _runningController,
        repository: repository,
        ownerUid: ownerUid,
      );

      _runSync = RunSyncController(
        ownerUid: ownerUid,
        runsRepository: repository,
        queueRepository: LocalRunSyncRepository(database: database),
        syncService: RunSyncService(),
      );

      _runSync!.addListener(_onSyncChanged);

      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        currentUser,
      ) {
        if (!mounted || currentUser?.uid == _ownerUid) return;

        _disposeRunSync();
        _syncStateRequest++;

        setState(() {
          _storageReady = false;
          _syncEntry = null;
          _syncStateError = null;
          _initializationError =
              'A conta foi alterada. Reabra a página de corrida.';
        });

        unawaited(_pauseAndSave());
      });

      setState(() {
        _storageReady = true;
      });

      _runSync!.start();
    } catch (_) {
      _disposeRunSync();

      if (!mounted) return;

      setState(() {
        _initializationError =
            'Não foi possível preparar o armazenamento das corridas. '
            'Confira se está conectado à sua conta e tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _disposeRunSync() {
    final sync = _runSync;
    _runSync = null;

    if (sync != null) {
      sync.removeListener(_onSyncChanged);
      sync.dispose();
    }
  }

  void _onSyncChanged() {
    if (!mounted) return;

    setState(() {});
    unawaited(_refreshSyncState());
  }

  Future<void> _refreshSyncState() async {
    final request = ++_syncStateRequest;
    final sync = _runSync;
    final session = _runningController.session;

    if (!mounted) return;

    if (!_isOwner ||
        sync == null ||
        session == null ||
        session.status != RunStatus.finished) {
      setState(() {
        _syncEntry = null;
        _syncStateError = null;
      });
      return;
    }

    final runId = session.id;

    try {
      final entry = await sync.getState(runId);

      if (!mounted ||
          !_isOwner ||
          request != _syncStateRequest ||
          _runningController.session?.id != runId) {
        return;
      }

      setState(() {
        _syncEntry = entry;
        _syncStateError = null;
      });
    } catch (_) {
      if (!mounted ||
          !_isOwner ||
          request != _syncStateRequest ||
          _runningController.session?.id != runId) {
        return;
      }

      setState(() {
        _syncStateError =
            'Não foi possível consultar o estado da sincronização.';
      });
    }
  }

  String _syncLabel() {
    if (_syncStateError != null) return _syncStateError!;

    final autosave = _autosave;

    if (autosave?.errorMessage != null || autosave?.hasPendingChanges == true) {
      return 'Aguardando confirmação do salvamento no aparelho.';
    }

    return switch (_syncEntry?.status) {
      RunSyncStatus.synced => 'Sincronizada com sua conta.',
      RunSyncStatus.failed =>
        _syncEntry?.lastError ?? 'Não foi possível sincronizar agora.',
      RunSyncStatus.pending => 'Na fila de sincronização.',
      null => 'Aguardando sincronização.',
    };
  }

  Future<void> _retrySync() async {
    final sync = _runSync;
    final session = _runningController.session;

    if (_isBusy ||
        sync == null ||
        sync.isSyncing ||
        session == null ||
        session.status != RunStatus.finished) {
      return;
    }

    setState(() => _actionInProgress = true);

    try {
      await sync.retryRun(session.id);
      await _refreshSyncState();
    } catch (_) {
      _showMessage('Não foi possível solicitar outro envio.');
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final sync = _runSync;

      if (_isOwner && sync != null) {
        unawaited(sync.syncPending());
        unawaited(_refreshSyncState());
      }

      return;
    }

    if (state == AppLifecycleState.detached) {
      unawaited(_pauseAndSave());
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_supportsBackgroundTracking) {
        unawaited(_saveCheckpoint());
      } else {
        unawaited(_pauseAndSave());
      }
    }
  }

  Future<void> _saveCheckpoint() async {
    final autosave = _autosave;

    if (autosave != null) {
      await autosave.flush();
    }
  }

  Future<void> _pauseAndSave() async {
    await _runningController.pause();

    final autosave = _autosave;
    if (autosave != null) {
      await autosave.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _syncStateRequest++;
    _disposeRunSync();

    final subscription = _authSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    unawaited(_runningController.pause());

    final autosave = _autosave;

    if (autosave != null) {
      unawaited(autosave.flush());
      autosave.dispose();
    }

    _runningController.dispose();
    _mapController.dispose();

    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _centerMap(LatLng location) {
    if (_mapReady) {
      _mapController.move(location, 17);
    }
  }

  Future<void> _findMyLocation() async {
    if (_isBusy) return;

    final session = _runningController.session;
    final lastPosition = _runningController.lastPosition;

    if (session != null) {
      if (lastPosition != null) {
        _centerMap(LatLng(lastPosition.latitude, lastPosition.longitude));
        return;
      }

      if (session.points.isNotEmpty) {
        final point = session.points.last;

        _centerMap(LatLng(point.latitude, point.longitude));
        return;
      }
    }

    setState(() => _isLocating = true);

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted || !_isOwner) return;

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _locatedPosition = location;
        _locatedAccuracy = position.accuracy;
      });

      _centerMap(location);
    } on LocationAccessException catch (error) {
      _showMessage(error.message);
    } on TimeoutException {
      _showMessage(
        'Não conseguimos localizar você a tempo. '
        'Tente novamente em um local aberto.',
      );
    } catch (_) {
      _showMessage('Não foi possível obter sua localização.');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<bool> _ensureRunNotificationPermission() async {
    final granted = await _notificationPermissionService.ensurePermission();

    if (!mounted || !_isOwner) return false;
    if (granted) return true;

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permitir notificações'),
        content: const Text(
          'O Okan usa uma notificação para mostrar quando o registro '
          'da corrida está ativo, inclusive com a tela bloqueada. '
          'Ative as notificações nas configurações do aplicativo '
          'e depois tente iniciar ou retomar a corrida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abrir configurações'),
          ),
        ],
      ),
    );

    if (!mounted || !_isOwner) return false;

    if (openSettings == true) {
      final opened = await _notificationPermissionService.openAppSettings();

      if (!opened) {
        _showMessage(
          'Abra as configurações do celular e permita '
          'as notificações do Okan.',
        );
      }
    }

    // Depois de voltar das configurações, o usuário toca novamente
    // em Iniciar ou Retomar. Não iniciamos a captura automaticamente.
    return false;
  }

  Future<void> _activateRun({bool resuming = false}) async {
    if (_isBusy) return;

    if (_autosave?.errorMessage != null) {
      _showMessage('Tente salvar os dados pendentes antes de continuar.');
      return;
    }

    setState(() => _actionInProgress = true);

    try {
      final granted = await _ensureRunNotificationPermission();

      if (!mounted || !_isOwner || !granted) return;

      // A solicitação de permissão pode abrir outra tela.
      // O serviço precisa ser iniciado com o aplicativo visível.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _showMessage(
          'Volte à tela de corrida e toque novamente em Iniciar ou Retomar.',
        );
        return;
      }

      if (resuming) {
        await _runningController.resume();
      } else {
        await _runningController.start();
      }

      if (!mounted) return;

      final lifecycle = WidgetsBinding.instance.lifecycleState;

      final isInBackground =
          lifecycle == AppLifecycleState.hidden ||
          lifecycle == AppLifecycleState.paused;

      if (!_isOwner ||
          lifecycle == AppLifecycleState.detached ||
          (isInBackground && !_supportsBackgroundTracking)) {
        await _pauseAndSave();
        return;
      }

      final autosave = _autosave;

      if (autosave != null) {
        final saved = await autosave.flush();

        if (!saved) {
          await _runningController.pause();

          _showMessage(
            'A corrida foi pausada porque o salvamento não foi confirmado.',
          );

          return;
        }
      }

      final position = _runningController.lastPosition;

      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _runningController.isRecording &&
          position != null) {
        _centerMap(LatLng(position.latitude, position.longitude));
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao preparar a corrida: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Não foi possível preparar a corrida. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _pauseRun() async {
    if (_isBusy) return;

    setState(() => _actionInProgress = true);

    try {
      await _pauseAndSave();
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _finishRun() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar corrida?'),
        content: const Text(
          'A captura será encerrada e o resultado será salvo no aparelho. '
          'Depois tentaremos sincronizar com sua conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (!mounted || !_isOwner || confirmed != true) return;

    setState(() => _actionInProgress = true);

    try {
      await _runningController.finish();

      final saved = await _autosave!.flush();

      if (!mounted || !_isOwner) return;

      _showMessage(
        saved
            ? 'Corrida salva no aparelho. Sincronização solicitada.'
            : 'O salvamento falhou. Use “Tentar salvar novamente”.',
      );

      await _refreshSyncState();

      final sync = _runSync;

      if (saved && sync != null) {
        unawaited(sync.syncPending());
      }
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _prepareNewRun() async {
    if (_isBusy) return;

    setState(() => _actionInProgress = true);

    try {
      final saved = await _autosave!.flush();

      if (!mounted || !_isOwner) return;

      if (!saved) {
        _showMessage(
          'Salve o resultado pendente antes de preparar outra corrida.',
        );
        return;
      }

      // Limpa somente o resumo da tela.
      // O resultado continua no banco local.
      _runningController.clearFinishedSession();
      _syncStateRequest++;

      setState(() {
        _syncEntry = null;
        _syncStateError = null;
      });
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _retrySave() async {
    if (_isBusy) return;

    setState(() => _actionInProgress = true);

    try {
      final saved = await _autosave!.retry();

      if (!mounted || !_isOwner) return;

      _showMessage(
        saved
            ? 'Dados salvos no aparelho.'
            : 'Ainda não foi possível salvar. Tente novamente.',
      );

      await _refreshSyncState();

      final sync = _runSync;

      if (saved && sync != null) {
        unawaited(sync.syncPending());
      }
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  Future<void> _openMapCredits() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
      );

      if (!opened) {
        _showMessage('Não foi possível abrir os créditos do mapa.');
      }
    } catch (_) {
      _showMessage('Não foi possível abrir os créditos do mapa.');
    }
  }

  Future<void> _openHistory() async {
    final repository = _repository;
    final syncController = _runSync;
    final ownerUid = _ownerUid;

    if (_isBusy ||
        repository == null ||
        syncController == null ||
        ownerUid == null) {
      return;
    }

    setState(() => _actionInProgress = true);

    try {
      // Consultar o histórico pausa uma corrida em andamento.
      await _pauseAndSave();

      if (!mounted || !_isOwner) return;

      if (_autosave?.errorMessage != null) {
        _showMessage('Salve os dados pendentes antes de abrir o histórico.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RunningHistoryPage(
            repository: repository,
            ownerUid: ownerUid,
            syncController: syncController,
          ),
        ),
      );

      if (mounted && _isOwner) {
        await _refreshSyncState();
      }
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      }
    }
  }

  List<Polyline> _buildPolylines(RunSession? session) {
    if (session == null) return [];

    final segments = <int, List<LatLng>>{};

    for (final point in session.points) {
      segments
          .putIfAbsent(point.segmentIndex, () => [])
          .add(LatLng(point.latitude, point.longitude));
    }

    return [
      for (final points in segments.values)
        if (points.length >= 2)
          Polyline(
            points: points,
            strokeWidth: 5,
            color: AppColors.primary,
            borderStrokeWidth: 2,
            borderColor: Colors.black,
          ),
    ];
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _formatPace(RunSession? session) {
    if (session == null || session.distanceMeters < 20) return '—';

    final pace = session.averagePaceSecondsPerKm;

    if (pace == null || !pace.isFinite) return '—';

    final totalSeconds = pace.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String _statusLabel(RunSession? session) {
    return switch (session?.status) {
      RunStatus.recording => 'Registrando corrida',
      RunStatus.paused => 'Corrida pausada',
      RunStatus.finished => 'Corrida finalizada',
      null => 'Pronto para começar',
    };
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSub, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(RunSession? session) {
    if (session == null) {
      return ElevatedButton.icon(
        onPressed: _isBusy ? null : () => _activateRun(),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar corrida'),
      );
    }

    if (session.status == RunStatus.finished) {
      return OutlinedButton.icon(
        onPressed: _isBusy ? null : _prepareNewRun,
        icon: const Icon(Icons.add),
        label: const Text('Nova corrida'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isBusy
                ? null
                : session.status == RunStatus.recording
                ? _pauseRun
                : () => _activateRun(resuming: true),
            icon: Icon(
              session.status == RunStatus.recording
                  ? Icons.pause
                  : Icons.play_arrow,
            ),
            label: Text(
              session.status == RunStatus.recording ? 'Pausar' : 'Retomar',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _finishRun,
            icon: const Icon(Icons.stop),
            label: const Text('Finalizar'),
          ),
        ),
      ],
    );
  }

  String _storageLabel(RunSession? session) {
    final autosave = _autosave;

    if (session == null) return 'Armazenamento local pronto.';
    if (autosave?.errorMessage != null) return autosave!.errorMessage!;
    if (autosave?.isSaving == true) return 'Salvando no aparelho...';
    if (autosave?.hasPendingChanges == true) {
      return 'Aguardando o próximo salvamento.';
    }

    return 'Dados salvos no aparelho.';
  }

  @override
  Widget build(BuildContext context) {
    if (!_storageReady) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Corrida'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isInitializing
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _initializationError ??
                            'Preparando o armazenamento local...',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _ownerUid == null
                            ? _initializeStorage
                            : null,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    final autosave = _autosave!;

    return AnimatedBuilder(
      animation: Listenable.merge([_runningController, autosave]),
      builder: (context, child) {
        final session = _runningController.session;
        final position = _runningController.lastPosition;

        LatLng? markerPosition = _locatedPosition;
        double? accuracy = _locatedAccuracy;

        if (session != null) {
          if (position != null) {
            markerPosition = LatLng(position.latitude, position.longitude);
            accuracy = position.accuracy;
          } else if (session.points.isNotEmpty) {
            final point = session.points.last;
            markerPosition = LatLng(point.latitude, point.longitude);
            accuracy = point.accuracyMeters;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Corrida'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textMain,
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: markerPosition ?? _initialCenter,
                    initialZoom: session == null ? 14 : 17,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: () => _mapReady = true,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sankofa.okan',
                      maxNativeZoom: 19,
                    ),
                    PolylineLayer(polylines: _buildPolylines(session)),
                    if (markerPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: markerPosition,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    SimpleAttributionWidget(
                      source: const Text(
                        'OpenStreetMap contributors',
                        style: TextStyle(color: Colors.black, fontSize: 11),
                      ),
                      backgroundColor: Colors.white,
                      onTap: _openMapCredits,
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _statusLabel(session),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _metric(
                              'Tempo ativo',
                              _formatDuration(
                                _runningController.activeDuration,
                              ),
                            ),
                            _metric(
                              'Distância · km',
                              (session?.distanceKm ?? 0).toStringAsFixed(2),
                            ),
                            _metric('Ritmo · min/km', _formatPace(session)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          accuracy == null
                              ? 'Localize-se para conferir o sinal do GPS.'
                              : 'Precisão da última posição: '
                                    '${accuracy.toStringAsFixed(0)} metros.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSub),
                        ),
                        if (_runningController.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _runningController.message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _storageLabel(session),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: autosave.errorMessage == null
                                ? AppColors.textSub
                                : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        if (autosave.errorMessage != null)
                          TextButton.icon(
                            onPressed: _isBusy ? null : _retrySave,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar salvar novamente'),
                          ),
                        if (session?.status == RunStatus.finished) ...[
                          const SizedBox(height: 8),
                          Text(
                            _syncLabel(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  _syncEntry?.status == RunSyncStatus.failed ||
                                      _syncStateError != null
                                  ? Colors.orange
                                  : AppColors.textSub,
                              fontSize: 12,
                            ),
                          ),
                          if (_syncEntry?.status == RunSyncStatus.failed)
                            TextButton.icon(
                              onPressed: _isBusy || _runSync?.isSyncing == true
                                  ? null
                                  : _retrySync,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Tentar sincronizar novamente'),
                            ),
                        ],
                        if (_runSync?.isSyncing == true) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Sincronizando corridas...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSub,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_isBusy || autosave.isSaving) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: 12),
                        _buildActions(session),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _openHistory,
                          icon: const Icon(Icons.history),
                          label: const Text('Histórico de corridas'),
                        ),
                        TextButton.icon(
                          onPressed: _isBusy ? null : _findMyLocation,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            session == null
                                ? 'Minha localização'
                                : 'Centralizar última posição',
                          ),
                        ),
                        Text(
                          _supportsBackgroundTracking
                              ? 'Durante a corrida, você pode bloquear a tela ou usar outro app. '
                                    'A notificação indica que o registro está ativo. '
                                    'Os resultados são salvos neste aparelho e sincronizados '
                                    'com sua conta quando houver conexão com o servidor.'
                              : 'Mantenha o app aberto durante a gravação. '
                                    'Sair ou bloquear a tela pausa a corrida. '
                                    'Os resultados são salvos neste aparelho e sincronizados '
                                    'com sua conta quando houver conexão com o servidor.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

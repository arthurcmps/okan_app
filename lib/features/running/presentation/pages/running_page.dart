import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/location_tracking_service.dart';
import '../../domain/entities/run_session.dart';
import '../controllers/running_controller.dart';

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

  LatLng? _locatedPosition;
  double? _locatedAccuracy;
  bool _isLocating = false;

  bool get _isBusy => _isLocating || _runningController.isBusy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Neste protótipo, sair do app ou bloquear a tela pausa a corrida.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_runningController.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _findMyLocation() async {
    if (_isBusy) return;

    // Durante ou depois de uma corrida, centraliza na última posição.
    final lastPosition = _runningController.lastPosition;

    if (_runningController.session != null && lastPosition != null) {
      _mapController.move(
        LatLng(lastPosition.latitude, lastPosition.longitude),
        17,
      );
      return;
    }

    setState(() => _isLocating = true);

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _locatedPosition = location;
        _locatedAccuracy = position.accuracy;
      });

      _mapController.move(location, 17);
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

  Future<void> _activateRun({bool resuming = false}) async {
    if (_isBusy) return;

    if (resuming) {
      await _runningController.resume();
    } else {
      await _runningController.start();
    }

    if (!mounted) return;

    // Trata também a saída do app enquanto a posição inicial era obtida.
    final lifecycle = WidgetsBinding.instance.lifecycleState;

    if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      await _runningController.pause();
      return;
    }

    final position = _runningController.lastPosition;

    if (_runningController.isRecording && position != null) {
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    }
  }

  Future<void> _finishRun() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar corrida?'),
        content: const Text(
          'A captura será encerrada e o resumo ficará nesta tela. '
          'O salvamento ainda não foi implementado.',
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

    if (!mounted || confirmed != true) return;

    await _runningController.finish();
  }

  Future<void> _clearFinishedRun() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preparar outra corrida?'),
        content: const Text(
          'O resultado atual será descartado. '
          'Neste protótipo, ele ainda não foi salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Manter resultado'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    _runningController.clearFinishedSession();
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
    // Evita exibir um ritmo instável nos primeiros metros.
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
        onPressed: _isBusy ? null : _clearFinishedRun,
        icon: const Icon(Icons.add),
        label: const Text('Preparar outra corrida'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isBusy
                ? null
                : session.status == RunStatus.recording
                ? () => _runningController.pause()
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runningController,
      builder: (context, child) {
        final session = _runningController.session;
        final position = _runningController.lastPosition;

        final markerPosition = position == null
            ? _locatedPosition
            : LatLng(position.latitude, position.longitude);

        final accuracy = position?.accuracy ?? _locatedAccuracy;

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
                  options: const MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 14,
                    minZoom: 3,
                    maxZoom: 19,
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
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
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
                              : 'Precisão estimada: '
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
                        if (_isBusy) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: 12),
                        _buildActions(session),
                        TextButton.icon(
                          onPressed: _isBusy ? null : _findMyLocation,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            session == null
                                ? 'Minha localização'
                                : 'Centralizar última posição',
                          ),
                        ),
                        const Text(
                          'Protótipo: mantenha o app aberto. '
                          'Sair do app ou bloquear a tela pausa a corrida. '
                          'Os dados ainda não são salvos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/local_run_sync_repository.dart';
import '../controllers/run_sync_controller.dart';
import 'run_share_preview_page.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/run_session.dart';
import '../../domain/repositories/runs_repository.dart';

String _durationText(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

  return '$hours:$minutes:$seconds';
}

String _paceText(RunSession session) {
  if (session.distanceMeters < 20) return '—';

  final pace = session.averagePaceSecondsPerKm;
  if (pace == null || !pace.isFinite) return '—';

  final total = pace.round();
  final seconds = (total % 60).toString().padLeft(2, '0');

  return '${total ~/ 60}:$seconds min/km';
}

String _dateText(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

class RunningHistoryPage extends StatefulWidget {
  const RunningHistoryPage({
    super.key,
    required this.repository,
    required this.ownerUid,
    required this.syncController,
  });

  final RunsRepository repository;
  final String ownerUid;
  final RunSyncController syncController;

  @override
  State<RunningHistoryPage> createState() => _RunningHistoryPageState();
}

class _RunningHistoryPageState extends State<RunningHistoryPage> {
  static const _pageSize = 20;

  final List<RunSession> _sessions = [];
  final Map<String, RunSyncQueueEntry?> _syncStates = {};

  StreamSubscription<User?>? _authSubscription;

  bool _loading = false;
  bool _hasMore = true;
  bool _syncReadFailed = false;

  String? _error;
  String? _retryingRunId;

  int _syncRequest = 0;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;

  @override
  void initState() {
    super.initState();

    widget.syncController.addListener(_onSyncChanged);

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == widget.ownerUid) return;

      _syncRequest++;

      setState(() {
        _sessions.clear();
        _syncStates.clear();
        _error = 'A conta foi alterada. Reabra o histórico.';
      });
    });

    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _syncRequest++;

    // O controlador pertence à página de corrida.
    // Aqui removemos apenas o listener do histórico.
    widget.syncController.removeListener(_onSyncChanged);

    final subscription = _authSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }

  void _onSyncChanged() {
    if (!mounted || !_isOwner) return;

    setState(() {});
    unawaited(_refreshSyncStates());
  }

  Future<void> _refreshSyncStates() async {
    if (!mounted || !_isOwner || _loading) return;

    final request = ++_syncRequest;
    final runIds = _sessions.map((session) => session.id).toList();

    try {
      final entries = await Future.wait<RunSyncQueueEntry?>(
        runIds.map(widget.syncController.getState),
      );

      if (!mounted || !_isOwner || request != _syncRequest) return;

      setState(() {
        _syncStates.clear();

        for (var index = 0; index < runIds.length; index++) {
          _syncStates[runIds[index]] = entries[index];
        }

        _syncReadFailed = false;
      });
    } catch (_) {
      if (!mounted || !_isOwner || request != _syncRequest) return;

      setState(() => _syncReadFailed = true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || !_isOwner) return;

    // Invalida consultas de sincronização anteriores.
    _syncRequest++;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await widget.repository.getFinishedSessions(
        ownerUid: widget.ownerUid,
        limit: _pageSize,
        offset: reset ? 0 : _sessions.length,
      );

      if (!mounted || !_isOwner) return;

      setState(() {
        if (reset) {
          _sessions.clear();
          _syncStates.clear();
        }

        _sessions.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      if (!mounted || !_isOwner) return;

      setState(() {
        _error = 'Não foi possível carregar as corridas.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);

        if (_isOwner) {
          await _refreshSyncStates();
        }
      }
    }
  }

  Future<void> _refreshHistory() async {
    await _load(reset: true);

    if (!mounted || !_isOwner) return;

    // Solicita o envio das corridas pendentes sem bloquear a lista.
    unawaited(widget.syncController.syncPending());
  }

  Future<void> _retrySync(String runId) async {
    if (!_isOwner ||
        _retryingRunId != null ||
        widget.syncController.isSyncing) {
      return;
    }

    setState(() => _retryingRunId = runId);

    try {
      await widget.syncController.retryRun(runId);

      if (!mounted || !_isOwner) return;

      await _refreshSyncStates();
    } catch (_) {
      if (!mounted || !_isOwner) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível solicitar o envio. '
            'A corrida continua salva neste aparelho.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingRunId = null);
      }
    }
  }

  void _openDetails(RunSession session) {
    if (!_isOwner) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _RunDetailsPage(session: session, ownerUid: widget.ownerUid),
      ),
    );
  }

  Widget _buildSyncStatus(RunSession session) {
    final entry = _syncStates[session.id];

    final String label;
    final IconData icon;
    final Color color;

    if (_syncReadFailed) {
      label = 'Estado de sincronização indisponível';
      icon = Icons.cloud_off_outlined;
      color = Colors.orange;
    } else {
      switch (entry?.status) {
        case RunSyncStatus.synced:
          label = 'Sincronizada';
          icon = Icons.cloud_done_outlined;
          color = Colors.green;

        case RunSyncStatus.failed:
          label = 'Falha na sincronização';
          icon = Icons.cloud_off_outlined;
          color = Colors.orange;

        case RunSyncStatus.pending:
          label = 'Pendente de sincronização';
          icon = Icons.cloud_upload_outlined;
          color = AppColors.textSub;

        case null:
          label = _syncStates.containsKey(session.id)
              ? 'Estado de sincronização não encontrado'
              : 'Consultando sincronização...';
          icon = Icons.cloud_outlined;
          color = AppColors.textSub;
      }
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildSessionCard(RunSession session) {
    final entry = _syncStates[session.id];
    final failed = !_syncReadFailed && entry?.status == RunSyncStatus.failed;
    final retrying = _retryingRunId == session.id;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.directions_run, color: AppColors.primary),
            title: Text(_dateText(session.startedAt)),
            subtitle: Text(
              '${session.distanceKm.toStringAsFixed(2)} km'
              ' · ${_durationText(session.activeDuration)}'
              '\nRitmo: ${_paceText(session)}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetails(session),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSyncStatus(session),
                if (failed) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry?.lastError ??
                        'A corrida está salva neste aparelho. '
                            'Tente sincronizar novamente.',
                    style: const TextStyle(
                      color: AppColors.textSub,
                      fontSize: 12,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          !_isOwner ||
                              _retryingRunId != null ||
                              widget.syncController.isSyncing
                          ? null
                          : () => _retrySync(session.id),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        retrying
                            ? 'Tentando sincronizar...'
                            : 'Tentar sincronizar novamente',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _load(reset: _sessions.isEmpty),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Você ainda não tem corridas finalizadas neste aparelho.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: () => _load(),
          child: const Text('Carregar mais'),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Todas as corridas locais foram carregadas.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSub),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Histórico de corridas')),
      body: !_isOwner
          ? const Center(
              child: Text('Entre novamente para consultar suas corridas.'),
            )
          : Column(
              children: [
                if (widget.syncController.isSyncing)
                  const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshHistory,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _sessions.length) {
                          return _buildFooter();
                        }

                        return _buildSessionCard(_sessions[index]);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RunDetailsPage extends StatelessWidget {
  const _RunDetailsPage({required this.session, required this.ownerUid});

  final RunSession session;
  final String ownerUid;

  List<Polyline> _polylines() {
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

  void _openSharePreview(BuildContext context) {
    if (FirebaseAuth.instance.currentUser?.uid != ownerUid ||
        session.status != RunStatus.finished) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RunSharePreviewPage(session: session, ownerUid: ownerUid),
      ),
    );
  }

  Future<void> _openCredits(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir os créditos do mapa.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir os créditos do mapa.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.data?.uid != ownerUid) {
          return Scaffold(
            appBar: AppBar(title: const Text('Corrida')),
            body: const Center(
              child: Text('A conta foi alterada. Reabra o histórico.'),
            ),
          );
        }

        final coordinates = [
          for (final point in session.points)
            LatLng(point.latitude, point.longitude),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Detalhes da corrida')),
          body: Column(
            children: [
              Expanded(
                child: coordinates.isEmpty
                    ? const Center(
                        child: Text(
                          'Esta corrida não tem percurso registrado.',
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: coordinates.first,
                          initialZoom: 16,
                          initialCameraFit: coordinates.length >= 2
                              ? CameraFit.bounds(
                                  bounds: LatLngBounds.fromPoints(coordinates),
                                  padding: const EdgeInsets.all(32),
                                  maxZoom: 17,
                                )
                              : null,
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
                          PolylineLayer(polylines: _polylines()),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: coordinates.first,
                                width: 36,
                                height: 36,
                                child: const Icon(
                                  Icons.play_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                              ),
                              if (coordinates.length > 1)
                                Marker(
                                  point: coordinates.last,
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.orange,
                                    size: 32,
                                  ),
                                ),
                            ],
                          ),
                          SimpleAttributionWidget(
                            source: const Text(
                              'OpenStreetMap contributors',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            onTap: () => _openCredits(context),
                          ),
                        ],
                      ),
              ),
              SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _dateText(session.startedAt),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Distância: '
                          '${session.distanceKm.toStringAsFixed(2)} km\n'
                          'Tempo ativo: '
                          '${_durationText(session.activeDuration)}\n'
                          'Ritmo médio: ${_paceText(session)}\n'
                          'Trechos registrados: ${session.segmentCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMain),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Salva neste aparelho. '
                          'Pausas e lacunas aparecem como trechos separados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSub,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openSharePreview(context),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar corrida'),
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

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  final RunsRepository repository;
  final String ownerUid;

  @override
  State<RunningHistoryPage> createState() => _RunningHistoryPageState();
}

class _RunningHistoryPageState extends State<RunningHistoryPage> {
  static const _pageSize = 20;

  final List<RunSession> _sessions = [];

  StreamSubscription<User?>? _authSubscription;

  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;

  @override
  void initState() {
    super.initState();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == widget.ownerUid) return;

      setState(() {
        _sessions.clear();
        _error = 'A conta foi alterada. Reabra o histórico.';
      });
    });

    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    final subscription = _authSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || !_isOwner) return;

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
        if (reset) _sessions.clear();

        _sessions.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Não foi possível carregar as corridas.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length + 1,
                itemBuilder: (context, index) {
                  if (index == _sessions.length) {
                    return _buildFooter();
                  }

                  final session = _sessions[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.directions_run,
                        color: AppColors.primary,
                      ),
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
                  );
                },
              ),
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

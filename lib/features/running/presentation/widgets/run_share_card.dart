import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/run_session.dart';
import 'run_route_art.dart';

class RunShareCard extends StatelessWidget {
  const RunShareCard({
    super.key,
    required this.session,
    this.showRoute = false,
  });

  final RunSession session;
  final bool showRoute;

  static const _background = Color(0xFF120E16);
  static const _accent = Color(0xFFFFB347);

  String get _duration {
    final duration = session.activeDuration;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String get _pace {
    final secondsPerKm = session.averagePaceSecondsPerKm;

    if (session.distanceMeters < 20 ||
        secondsPerKm == null ||
        !secondsPerKm.isFinite) {
      return '—';
    }

    final total = secondsPerKm.round();
    final seconds = (total % 60).toString().padLeft(2, '0');

    return '${total ~/ 60}:$seconds';
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = NumberFormat('0.00', 'pt_BR').format(session.distanceKm);
    final date = DateFormat('dd/MM/yyyy').format(session.startedAt.toLocal());

    final hasRoute = session.points.any((point) => point.hasValidCoordinates);

    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 360,
        height: 640,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_background, Color(0xFF30203B), _background],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/images/logo_okan.png',
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'OKAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 96,
              child: showRoute && hasRoute
                  ? RunRouteArt(points: session.points)
                  : const Center(
                      child: Icon(
                        Icons.directions_run,
                        size: 64,
                        color: _accent,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'MAIS UM PERCURSO.\nMAIS UMA CONQUISTA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 72,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  distance,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 76,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const Text(
              'QUILÔMETROS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 3,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _metric(_duration, 'TEMPO ATIVO'),
                const SizedBox(width: 16),
                _metric(_pace, 'RITMO · MIN/KM'),
              ],
            ),
            const Spacer(),
            Text(
              date,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'MOVIMENTE SUA HISTÓRIA',
              textAlign: TextAlign.center,
              style: TextStyle(color: _accent, fontSize: 11, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

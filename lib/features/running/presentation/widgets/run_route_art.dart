import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/run_point.dart';

class RunRouteArt extends StatelessWidget {
  const RunRouteArt({
    super.key,
    required this.points,
    this.color = const Color(0xFFFFB347),
  });

  final List<RunPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Desenho do percurso da corrida',
      child: CustomPaint(
        painter: _RunRoutePainter(points: points, color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RunRoutePainter extends CustomPainter {
  const _RunRoutePainter({required this.points, required this.color});

  final List<RunPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final validPoints = points
        .where((point) => point.hasValidCoordinates)
        .toList(growable: false);

    if (validPoints.isEmpty || size.width <= 24 || size.height <= 24) {
      return;
    }

    final originLongitude = validPoints.first.longitude;

    var minLatitude = validPoints.first.latitude;
    var maxLatitude = minLatitude;

    for (final point in validPoints) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
    }

    final middleLatitude = (minLatitude + maxLatitude) / 2;
    final longitudeScale = math
        .cos(middleLatitude * math.pi / 180)
        .abs()
        .clamp(0.000001, 1.0)
        .toDouble();

    Offset project(RunPoint point) {
      // Mantém percursos próximos à linha internacional de data contínuos.
      final longitudeDelta =
          (point.longitude - originLongitude + 540) % 360 - 180;

      return Offset(
        longitudeDelta * longitudeScale,
        -(point.latitude - middleLatitude),
      );
    }

    final projected = validPoints.map(project).toList(growable: false);

    var minX = projected.first.dx;
    var maxX = minX;
    var minY = projected.first.dy;
    var maxY = minY;

    for (final point in projected) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final width = maxX - minX;
    final height = maxY - minY;

    final horizontalScale = width > 0
        ? (size.width - 24) / width
        : double.infinity;
    final verticalScale = height > 0
        ? (size.height - 24) / height
        : double.infinity;

    final candidateScale = math.min(horizontalScale, verticalScale);
    final scale = candidateScale.isFinite ? candidateScale : 1.0;

    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    Offset position(RunPoint point) {
      return (project(point) - center) * scale +
          Offset(size.width / 2, size.height / 2);
    }

    final route = Path();
    int? previousSegment;

    for (final point in points) {
      if (!point.hasValidCoordinates) {
        previousSegment = null;
        continue;
      }

      final location = position(point);

      if (previousSegment == point.segmentIndex) {
        route.lineTo(location.dx, location.dy);
      } else {
        route.moveTo(location.dx, location.dy);
      }

      previousSegment = point.segmentIndex;
    }

    canvas.drawPath(
      route,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      position(validPoints.first),
      5,
      Paint()..color = Colors.white,
    );

    if (validPoints.length > 1) {
      canvas.drawCircle(position(validPoints.last), 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RunRoutePainter oldDelegate) {
    return !identical(points, oldDelegate.points) || color != oldDelegate.color;
  }
}

import 'run_point.dart';

enum RunStatus { recording, paused, finished }

class RunSession {
  RunSession({
    required this.id,
    required this.startedAt,
    required this.status,
    this.endedAt,
    this.activeDuration = Duration.zero,
    this.distanceMeters = 0,
    List<RunPoint> points = const [],
  }) : points = List<RunPoint>.unmodifiable(points);

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final RunStatus status;
  final Duration activeDuration;
  final double distanceMeters;
  final List<RunPoint> points;

  double get distanceKm => distanceMeters / 1000;

  double? get averagePaceSecondsPerKm {
    if (!distanceMeters.isFinite ||
        distanceMeters <= 0 ||
        activeDuration <= Duration.zero) {
      return null;
    }

    final activeSeconds = activeDuration.inMilliseconds / 1000;

    return activeSeconds / distanceKm;
  }

  int get segmentCount =>
      points.map((point) => point.segmentIndex).toSet().length;

  RunSession copyWith({
    RunStatus? status,
    DateTime? endedAt,
    Duration? activeDuration,
    double? distanceMeters,
    List<RunPoint>? points,
  }) {
    return RunSession(
      id: id,
      startedAt: startedAt,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      activeDuration: activeDuration ?? this.activeDuration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      points: points ?? this.points,
    );
  }
}

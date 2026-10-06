class RunPoint {
  const RunPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.segmentIndex,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
  final int segmentIndex;

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  bool get hasValidAccuracy => accuracyMeters.isFinite && accuracyMeters >= 0;
}

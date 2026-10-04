import 'package:geolocator/geolocator.dart';

class LocationAccessException implements Exception {
  const LocationAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationTrackingService {
  const LocationTrackingService();

  Future<void> ensureAccess() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw const LocationAccessException(
        'Ative a localização do celular e tente novamente.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Libere a localização nas configurações do aplicativo.',
      );
    }

    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationAccessException(
        'Autorize a localização para registrar sua corrida.',
      );
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensureAccess();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Stream<Position> watchPositions() async* {
    await ensureAccess();

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}

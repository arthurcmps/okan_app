import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:okan_app/features/running/data/services/location_tracking_service.dart';
import 'package:okan_app/features/running/presentation/controllers/running_controller.dart';

class FakeLocationService extends LocationTrackingService {
  FakeLocationService(this.currentPosition);

  Position currentPosition;

  final updates = StreamController<Position>.broadcast();

  @override
  Future<void> ensureAccess() async {}

  @override
  Future<Position> getCurrentPosition() async => currentPosition;

  @override
  Stream<Position> watchPositions() => updates.stream;
}

Position sample({
  required DateTime timestamp,
  double latitude = -22.785,
  double longitude = -43.311,
  double accuracy = 5,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

// Permite entregar eventos do stream e concluir tarefas assíncronas.
Future<void> flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late DateTime initialTime;
  late FakeLocationService location;
  late RunningController controller;

  setUp(() {
    initialTime = DateTime.now();

    location = FakeLocationService(sample(timestamp: initialTime));

    controller = RunningController(locationService: location);
  });

  tearDown(() async {
    controller.dispose();
    await location.updates.close();
  });

  test('pausa congela o tempo e retomada cria outro segmento', () async {
    await controller.start();

    location.updates.add(
      sample(
        timestamp: initialTime.add(const Duration(seconds: 2)),
        latitude: -22.78495,
      ),
    );
    await flushEvents();

    expect(controller.isRecording, isTrue);
    expect(controller.session!.distanceMeters, greaterThan(0));

    await controller.pause();

    final pausedTime = controller.activeDuration;
    final distanceBeforeResume = controller.session!.distanceMeters;
    final pointsBeforeResume = controller.session!.points.length;

    // Simula deslocamento durante a pausa.
    location.updates.add(
      sample(
        timestamp: initialTime.add(const Duration(seconds: 3)),
        latitude: -22.780,
      ),
    );
    await flushEvents();

    expect(controller.activeDuration, pausedTime);
    expect(controller.session!.points.length, pointsBeforeResume);

    location.currentPosition = sample(
      timestamp: DateTime.now(),
      latitude: -22.780,
    );

    await controller.resume();

    expect(controller.isRecording, isTrue);
    expect(controller.session!.segmentCount, 2);
    expect(controller.session!.distanceMeters, distanceBeforeResume);

    await controller.finish();

    expect(controller.isFinished, isTrue);
    expect(controller.session!.endedAt, isNotNull);

    final finishedPoints = controller.session!.points.length;

    location.updates.add(sample(timestamp: DateTime.now(), latitude: -22.779));
    await flushEvents();

    expect(controller.session!.points.length, finishedPoints);
  });

  test('descarta baixa precisão, posição repetida e salto do GPS', () async {
    await controller.start();

    location.updates.add(
      sample(
        timestamp: initialTime.add(const Duration(seconds: 1)),
        latitude: -22.78495,
        accuracy: 100,
      ),
    );

    location.updates.add(sample(timestamp: initialTime));

    location.updates.add(
      sample(
        timestamp: initialTime.add(const Duration(seconds: 2)),
        longitude: -43.300,
      ),
    );

    await flushEvents();

    expect(controller.session!.points.length, 1);
    expect(controller.session!.distanceMeters, 0);
    expect(controller.isRecording, isTrue);
  });

  test('lacuna prolongada cria segmento sem somar o trecho ausente', () async {
    await controller.start();

    location.updates.add(
      sample(
        timestamp: initialTime.add(const Duration(seconds: 60)),
        latitude: -22.780,
      ),
    );
    await flushEvents();

    expect(controller.session!.points.length, 2);
    expect(controller.session!.segmentCount, 2);
    expect(controller.session!.distanceMeters, 0);
  });

  test('falha do GPS pausa a corrida e preserva os pontos', () async {
    await controller.start();

    final sessionId = controller.session!.id;
    final pointCount = controller.session!.points.length;

    location.updates.addError(StateError('Falha simulada do GPS'));
    await flushEvents();

    expect(controller.isPaused, isTrue);
    expect(controller.session!.id, sessionId);
    expect(controller.session!.points.length, pointCount);
    expect(controller.message, contains('pausada'));
    expect(controller.isBusy, isFalse);
  });

  test('não inicia com posição de baixa precisão', () async {
    location.currentPosition = sample(timestamp: initialTime, accuracy: 100);

    await controller.start();

    expect(controller.session, isNull);
    expect(controller.isRecording, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.message, contains('baixa precisão'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dev Firebase bootstrap is emulator-only and uses demo project', () async {
    final source = await File(
      'lib/core/services/firebase_environment_service.dart',
    ).readAsString();

    expect(source, contains("developmentProjectId = 'demo-okan-dev'"));
    expect(source, contains('useAuthEmulator'));
    expect(source, contains('useFirestoreEmulator'));
    expect(source, contains('useStorageEmulator'));
    expect(source, contains('useFunctionsEmulator'));
    expect(source, contains("region: 'us-central1'"));
    expect(source, contains("region: 'southamerica-east1'"));
    expect(source, isNot(contains('app-academia-2914d')));
  });

  test('main disables App Check and push through environment contract', () async {
    final source = await File('lib/main.dart').readAsString();

    expect(source, contains('FirebaseEnvironmentService.initialize(environment)'));
    expect(source, contains('environment.enableAppCheck'));
    expect(source, contains('environment.enablePushNotifications'));
    expect(source, contains('environment.isDevelopment'));
  });

  test('Android cleartext is enabled only in debug manifest', () async {
    final debugManifest = await File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsString();
    final releaseManifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(releaseManifest, isNot(contains('android:usesCleartextTraffic="true"')));
  });
}

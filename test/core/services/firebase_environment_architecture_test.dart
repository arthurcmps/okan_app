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
    expect(source, contains('Firebase.app().options.projectId'));
    expect(source, contains('defaultProjectId != developmentProjectId'));
    expect(source, isNot(contains('app-academia-2914d')));
    expect(source, isNot(contains('await app.delete()')));
  });

  test('Android debug disables native production Firebase DEFAULT auto-init', () async {
    final debugManifest = await File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsString();
    final releaseManifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(
      debugManifest,
      contains('com.google.firebase.provider.FirebaseInitProvider'),
    );
    expect(debugManifest, contains('tools:node="remove"'));
    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));

    expect(
      releaseManifest,
      isNot(contains('com.google.firebase.provider.FirebaseInitProvider')),
    );
    expect(releaseManifest, isNot(contains('android:usesCleartextTraffic="true"')));
  });

  test('main disables App Check and push through environment contract', () async {
    final source = await File('lib/main.dart').readAsString();

    expect(source, contains('FirebaseEnvironmentService.initialize(environment)'));
    expect(source, contains('environment.enableAppCheck'));
    expect(source, contains('environment.enablePushNotifications'));
    expect(source, contains('environment.isDevelopment'));
  });

  test('dev guards every remaining direct Mercado Pago client path', () async {
    final storeSource = await File(
      'lib/features/store/data/repositories/firebase_store_repository.dart',
    ).readAsString();
    final subscriptionSource = await File(
      'lib/features/auth/presentation/pages/professor_subscription_page.dart',
    ).readAsString();

    for (final source in [storeSource, subscriptionSource]) {
      expect(source, contains('enableExternalPayments'));
      expect(source, contains('https://api.mercadopago.com'));
      expect(
        source.indexOf('enableExternalPayments'),
        lessThan(source.indexOf('https://api.mercadopago.com')),
      );
    }
  });
}

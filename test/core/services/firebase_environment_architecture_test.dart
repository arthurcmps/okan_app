import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dev Firebase bootstrap is emulator-only and uses demo project', () async {
    final source = await File(
      'lib/core/services/firebase_environment_service.dart',
    ).readAsString();

    expect(source, contains('developmentFirebaseProjectId'));
    expect(source, contains('useAuthEmulator'));
    expect(source, contains('useFirestoreEmulator'));
    expect(source, contains('useStorageEmulator'));
    expect(source, contains('useFunctionsEmulator'));
    expect(source, contains("region: 'us-central1'"));
    expect(source, contains("region: 'southamerica-east1'"));
    expect(source, contains('Firebase.app().options.projectId'));
    expect(source, contains('_expectedProjectId(environment)'));
    expect(source, isNot(contains('await app.delete()')));
  });

  test('dev preserves the explicitly supplied emulator host', () async {
    final source = await File(
      'lib/core/services/firebase_environment_service.dart',
    ).readAsString();

    expect(
      RegExp('automaticHostMapping: false').allMatches(source).length,
      5,
    );
    expect(
      source,
      contains('Android Emulator callers already pass 10.0.2.2'),
    );
  });

  test('staging uses explicit cloud Firebase options and never emulators', () async {
    final configSource = await File(
      'lib/core/config/app_environment.dart',
    ).readAsString();
    final serviceSource = await File(
      'lib/core/services/firebase_environment_service.dart',
    ).readAsString();

    expect(configSource, contains('OKAN_STAGING_FIREBASE_PROJECT_ID'));
    expect(configSource, contains('OKAN_STAGING_FIREBASE_ANDROID_APP_ID'));
    expect(configSource, contains('OKAN_STAGING_FIREBASE_WEB_APP_ID'));
    expect(configSource, contains('OKAN_STAGING_FIREBASE_IOS_APP_ID'));
    expect(configSource, contains('productionFirebaseProjectId'));
    expect(configSource, contains('developmentFirebaseProjectId'));
    expect(
      configSource,
      contains("stagingFirebaseProjectId = 'okan-staging-24829'"),
    );
    expect(
      configSource,
      contains('normalizedProjectId != stagingFirebaseProjectId'),
    );
    expect(configSource, contains('enableExternalPayments => isProduction'));

    expect(serviceSource, contains('_stagingOptionsForCurrentPlatform'));
    expect(serviceSource, contains('environment.firebaseConfig!'));
    expect(serviceSource, contains('DefaultFirebaseOptions.currentPlatform'));
    expect(
      serviceSource.indexOf('if (!environment.usesFirebaseEmulators)'),
      lessThan(serviceSource.indexOf('useAuthEmulator')),
    );
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

  test('foreground and background bootstrap use the same environment contract', () async {
    final source = await File('lib/main.dart').readAsString();

    expect(source, contains('OkanEnvironmentConfig.current'));
    expect(source, contains('FirebaseEnvironmentService.initialize(environment)'));
    expect(source, contains('environment.enableAppCheck'));
    expect(source, contains('environment.enablePushNotifications'));
    expect(source, contains('environment.showEnvironmentBanner'));
    expect(source, isNot(contains('DefaultFirebaseOptions.currentPlatform')));
  });

  test('non-production guards every remaining direct Mercado Pago client path', () async {
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

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/config/app_environment.dart';

OkanFirebaseConfig _stagingConfig({
  String projectId = stagingFirebaseProjectId,
}) {
  return OkanFirebaseConfig(
    projectId: projectId,
    messagingSenderId: '123456789012',
    storageBucket: '$projectId.firebasestorage.app',
    webApiKey: 'web-api-key',
    webAppId: '1:123456789012:web:staging',
    webAuthDomain: '$projectId.firebaseapp.com',
    androidApiKey: 'android-api-key',
    androidAppId: '1:123456789012:android:staging',
    iosApiKey: 'ios-api-key',
    iosAppId: '1:123456789012:ios:staging',
    iosBundleId: 'com.sankofa.okan',
  );
}

void main() {
  group('OkanEnvironmentConfig', () {
    test('production is the safe default contract', () {
      final config = OkanEnvironmentConfig.fromValues(environment: 'prod');

      expect(config.isProduction, isTrue);
      expect(config.isStaging, isFalse);
      expect(config.isDevelopment, isFalse);
      expect(config.isNonProduction, isFalse);
      expect(config.usesFirebaseEmulators, isFalse);
      expect(config.enableAppCheck, isTrue);
      expect(config.enablePushNotifications, isTrue);
      expect(config.enableExternalPayments, isTrue);
      expect(config.showEnvironmentBanner, isFalse);
      expect(config.emulatorHost, isNull);
      expect(config.firebaseConfig, isNull);
      expect(config.appTitle, 'Okan App');
    });

    test('development requires an explicit emulator host', () {
      expect(
        () => OkanEnvironmentConfig.fromValues(environment: 'dev'),
        throwsStateError,
      );
    });

    test('development disables production-only integrations', () {
      final config = OkanEnvironmentConfig.fromValues(
        environment: 'dev',
        emulatorHost: '10.0.2.2',
      );

      expect(config.isDevelopment, isTrue);
      expect(config.isNonProduction, isTrue);
      expect(config.usesFirebaseEmulators, isTrue);
      expect(config.enableAppCheck, isFalse);
      expect(config.enablePushNotifications, isFalse);
      expect(config.enableExternalPayments, isFalse);
      expect(config.showEnvironmentBanner, isTrue);
      expect(config.emulatorHost, '10.0.2.2');
      expect(config.label, 'DEV • LOCAL');
    });

    test('staging requires explicit Firebase configuration', () {
      expect(
        () => OkanEnvironmentConfig.fromValues(environment: 'staging'),
        throwsStateError,
      );
    });

    test('staging is cloud-backed but keeps external payments disabled', () {
      final stagingFirebase = _stagingConfig();
      final config = OkanEnvironmentConfig.fromValues(
        environment: 'staging',
        stagingFirebaseConfig: stagingFirebase,
      );

      expect(config.isProduction, isFalse);
      expect(config.isStaging, isTrue);
      expect(config.isDevelopment, isFalse);
      expect(config.isNonProduction, isTrue);
      expect(config.usesFirebaseEmulators, isFalse);
      expect(config.enableAppCheck, isTrue);
      expect(config.enablePushNotifications, isTrue);
      expect(config.enableExternalPayments, isFalse);
      expect(config.showEnvironmentBanner, isTrue);
      expect(config.emulatorHost, isNull);
      expect(config.firebaseConfig, same(stagingFirebase));
      expect(config.firebaseConfig!.projectId, stagingFirebaseProjectId);
      expect(config.label, 'STAGING');
      expect(config.appTitle, 'Okan App [STAGING]');
    });

    test('staging rejects any Firebase project other than official staging', () {
      for (final projectId in [
        productionFirebaseProjectId,
        developmentFirebaseProjectId,
        'demo-other-project',
        'okan-staging-test',
        'another-cloud-project',
      ]) {
        expect(
          () => OkanEnvironmentConfig.fromValues(
            environment: 'staging',
            stagingFirebaseConfig: _stagingConfig(projectId: projectId),
          ),
          throwsStateError,
          reason: projectId,
        );
      }
    });

    test('unknown environment cannot silently fall back to production', () {
      expect(
        () => OkanEnvironmentConfig.fromValues(environment: 'banana'),
        throwsArgumentError,
      );
    });
  });
}

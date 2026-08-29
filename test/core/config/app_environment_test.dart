import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/config/app_environment.dart';

void main() {
  group('OkanEnvironmentConfig', () {
    test('production is the safe default contract', () {
      final config = OkanEnvironmentConfig.fromValues(environment: 'prod');

      expect(config.isDevelopment, isFalse);
      expect(config.usesFirebaseEmulators, isFalse);
      expect(config.enableAppCheck, isTrue);
      expect(config.enablePushNotifications, isTrue);
      expect(config.enableExternalPayments, isTrue);
      expect(config.emulatorHost, isNull);
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
      expect(config.usesFirebaseEmulators, isTrue);
      expect(config.enableAppCheck, isFalse);
      expect(config.enablePushNotifications, isFalse);
      expect(config.enableExternalPayments, isFalse);
      expect(config.emulatorHost, '10.0.2.2');
      expect(config.label, 'DEV • LOCAL');
    });

    test('staging cannot silently fall back to production', () {
      expect(
        () => OkanEnvironmentConfig.fromValues(environment: 'staging'),
        throwsUnsupportedError,
      );
    });

    test('unknown environment cannot silently fall back to production', () {
      expect(
        () => OkanEnvironmentConfig.fromValues(environment: 'banana'),
        throwsArgumentError,
      );
    });
  });
}

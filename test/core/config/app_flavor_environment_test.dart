import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/config/app_environment.dart';

void main() {
  group('OkanEnvironmentConfig flavor contract', () {
    test('prod flavor resolves to production without explicit OKAN_ENV', () {
      final value = OkanEnvironmentConfig.resolveEnvironmentValue(
        flavor: 'prod',
        environmentValue: 'prod',
        hasExplicitEnvironment: false,
      );

      expect(value, 'prod');
    });

    test('staging flavor resolves to staging without explicit OKAN_ENV', () {
      final value = OkanEnvironmentConfig.resolveEnvironmentValue(
        flavor: 'staging',
        environmentValue: 'prod',
        hasExplicitEnvironment: false,
      );

      expect(value, 'staging');
    });

    test('dev flavor resolves to development without explicit OKAN_ENV', () {
      final value = OkanEnvironmentConfig.resolveEnvironmentValue(
        flavor: 'dev',
        environmentValue: 'prod',
        hasExplicitEnvironment: false,
      );

      expect(value, 'dev');
    });

    test('matching explicit environments are accepted', () {
      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'prod',
          environmentValue: 'prod',
          hasExplicitEnvironment: true,
        ),
        'prod',
      );

      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'staging',
          environmentValue: 'staging',
          hasExplicitEnvironment: true,
        ),
        'staging',
      );

      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'dev',
          environmentValue: 'dev',
          hasExplicitEnvironment: true,
        ),
        'dev',
      );
    });

    test('environment aliases remain compatible with their flavor', () {
      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'prod',
          environmentValue: 'production',
          hasExplicitEnvironment: true,
        ),
        'prod',
      );

      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'staging',
          environmentValue: 'stage',
          hasExplicitEnvironment: true,
        ),
        'staging',
      );

      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'dev',
          environmentValue: 'development',
          hasExplicitEnvironment: true,
        ),
        'dev',
      );
    });

    test('dev flavor rejects production environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'dev',
          environmentValue: 'prod',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('dev flavor rejects staging environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'dev',
          environmentValue: 'staging',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('prod flavor rejects development environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'prod',
          environmentValue: 'dev',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('prod flavor rejects staging environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'prod',
          environmentValue: 'staging',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('staging flavor rejects production environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'staging',
          environmentValue: 'prod',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('staging flavor rejects development environment', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'staging',
          environmentValue: 'dev',
          hasExplicitEnvironment: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown flavor fails closed', () {
      expect(
        () => OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: 'unknown',
          environmentValue: 'prod',
          hasExplicitEnvironment: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('no flavor preserves legacy environment resolution', () {
      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: null,
          environmentValue: 'dev',
          hasExplicitEnvironment: true,
        ),
        'dev',
      );

      expect(
        OkanEnvironmentConfig.resolveEnvironmentValue(
          flavor: '',
          environmentValue: 'staging',
          hasExplicitEnvironment: true,
        ),
        'staging',
      );
    });
  });
}

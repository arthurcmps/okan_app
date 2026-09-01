import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/config/app_environment.dart';
import 'package:okan_app/core/services/crash_reporting_service.dart';

class _RecordedError {
  const _RecordedError({
    required this.error,
    required this.stackTrace,
    required this.fatal,
    required this.reason,
  });

  final Object error;
  final StackTrace stackTrace;
  final bool fatal;
  final String? reason;
}

class _FakeCrashReportingBackend implements CrashReportingBackend {
  final List<bool> collectionValues = <bool>[];

  final Map<String, Object> customKeys = <String, Object>{};

  final List<_RecordedError> recordedErrors = <_RecordedError>[];

  final List<String> logs = <String>[];

  final List<FlutterErrorDetails> flutterFatalErrors = <FlutterErrorDetails>[];

  bool throwOnCollection = false;
  bool throwOnCustomKey = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (throwOnCollection) {
      throw StateError('collection failure');
    }

    collectionValues.add(enabled);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    if (throwOnCustomKey) {
      throw StateError('custom key failure');
    }

    customKeys[key] = value;
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    flutterFatalErrors.add(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    recordedErrors.add(
      _RecordedError(
        error: error,
        stackTrace: stackTrace,
        fatal: fatal,
        reason: reason,
      ),
    );
  }

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }
}

OkanEnvironmentConfig _productionEnvironment() {
  return OkanEnvironmentConfig.fromValues(environment: 'prod');
}

OkanEnvironmentConfig _developmentEnvironment() {
  return OkanEnvironmentConfig.fromValues(
    environment: 'dev',
    emulatorHost: '127.0.0.1',
  );
}

OkanEnvironmentConfig _stagingEnvironment() {
  return OkanEnvironmentConfig.fromValues(
    environment: 'staging',
    stagingFirebaseConfig: const OkanFirebaseConfig(
      projectId: stagingFirebaseProjectId,
      messagingSenderId: '123456789012',
      storageBucket: 'okan-staging-24829.firebasestorage.app',
      webApiKey: 'web-api-key',
      webAppId: '1:123456789012:web:staging',
      webAuthDomain: 'okan-staging-24829.firebaseapp.com',
      androidApiKey: 'android-api-key',
      androidAppId: '1:123456789012:android:staging',
      iosApiKey: 'ios-api-key',
      iosAppId: '1:123456789012:ios:staging',
      iosBundleId: 'com.sankofa.okan',
    ),
  );
}

void main() {
  group('CrashReportingService.initialize', () {
    test('automatic platform detection allows Android', () async {
      final originalPlatform = debugDefaultTargetPlatformOverride;

      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final backend = _FakeCrashReportingBackend();
        final service = CrashReportingService(backend: backend);

        await service.initialize(_productionEnvironment());

        expect(service.isEnabled, isTrue);
        expect(backend.collectionValues, <bool>[true]);
        expect(backend.customKeys, <String, Object>{
          'okan_environment': 'PROD',
          'okan_platform': 'android',
        });
      } finally {
        debugDefaultTargetPlatformOverride = originalPlatform;
      }
    });

    test('automatic platform detection keeps Apple fail-closed', () async {
      final originalPlatform = debugDefaultTargetPlatformOverride;

      try {
        for (final platform in <TargetPlatform>[
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ]) {
          debugDefaultTargetPlatformOverride = platform;

          final backend = _FakeCrashReportingBackend();
          final service = CrashReportingService(backend: backend);

          await service.initialize(_productionEnvironment());

          expect(
            service.isEnabled,
            isFalse,
            reason:
                '$platform must remain disabled until Apple Firebase '
                'identity is valid.',
          );
          expect(
            backend.collectionValues,
            isEmpty,
            reason: '$platform must not touch Crashlytics collection.',
          );
          expect(
            backend.customKeys,
            isEmpty,
            reason: '$platform must not attach Crashlytics metadata.',
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = originalPlatform;
      }
    });
    test('production enables collection and attaches safe metadata', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_productionEnvironment());

      expect(service.isEnabled, isTrue);
      expect(backend.collectionValues, <bool>[true]);

      expect(backend.customKeys, <String, Object>{
        'okan_environment': 'PROD',
        'okan_platform': 'android',
      });
    });

    test('staging enables collection and attaches safe metadata', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_stagingEnvironment());

      expect(service.isEnabled, isTrue);
      expect(backend.collectionValues, <bool>[true]);

      expect(backend.customKeys, <String, Object>{
        'okan_environment': 'STAGING',
        'okan_platform': 'android',
      });
    });

    test('development explicitly disables collection', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_developmentEnvironment());

      expect(service.isEnabled, isFalse);
      expect(backend.collectionValues, <bool>[false]);
      expect(backend.customKeys, isEmpty);
    });

    test('unsupported platform never touches native backend', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: false,
        platformLabel: 'windows',
      );

      await service.initialize(_productionEnvironment());

      expect(service.isEnabled, isFalse);
      expect(backend.collectionValues, isEmpty);
      expect(backend.customKeys, isEmpty);
    });

    test('collection configuration failure keeps service disabled', () async {
      final backend = _FakeCrashReportingBackend()..throwOnCollection = true;

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_productionEnvironment());

      expect(service.isEnabled, isFalse);
      expect(backend.customKeys, isEmpty);
    });

    test('metadata failure does not disable crash reporting', () async {
      final backend = _FakeCrashReportingBackend()..throwOnCustomKey = true;

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_productionEnvironment());

      expect(service.isEnabled, isTrue);
      expect(backend.collectionValues, <bool>[true]);
    });
  });

  group('CrashReportingService reporting', () {
    test(
      'installed platform handler preserves previous handler and reports fatal async error',
      () async {
        final backend = _FakeCrashReportingBackend();

        final service = CrashReportingService(
          backend: backend,
          platformSupported: true,
          platformLabel: 'android',
        );

        await service.initialize(_productionEnvironment());

        final originalHandler = PlatformDispatcher.instance.onError;

        var previousHandlerCalled = false;

        PlatformDispatcher.instance.onError = (_, __) {
          previousHandlerCalled = true;
          return false;
        };

        try {
          service.installPlatformErrorHandler();

          final error = StateError('async fatal test');

          final stackTrace = StackTrace.current;

          final handled =
              PlatformDispatcher.instance.onError?.call(error, stackTrace) ??
              false;

          await Future<void>.delayed(Duration.zero);

          expect(previousHandlerCalled, isTrue);

          expect(handled, isTrue);

          expect(backend.recordedErrors, hasLength(1));

          final recorded = backend.recordedErrors.single;

          expect(recorded.error, same(error));

          expect(recorded.stackTrace, same(stackTrace));

          expect(recorded.fatal, isTrue);

          expect(recorded.reason, 'uncaught_async_error');
        } finally {
          PlatformDispatcher.instance.onError = originalHandler;
        }
      },
    );

    test('installed platform handler stays disabled in development', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_developmentEnvironment());

      final originalHandler = PlatformDispatcher.instance.onError;

      PlatformDispatcher.instance.onError = null;

      try {
        service.installPlatformErrorHandler();

        final handled =
            PlatformDispatcher.instance.onError?.call(
              StateError('must not be sent'),
              StackTrace.current,
            ) ??
            false;

        await Future<void>.delayed(Duration.zero);

        expect(handled, isFalse);

        expect(backend.recordedErrors, isEmpty);
      } finally {
        PlatformDispatcher.instance.onError = originalHandler;
      }
    });
    test(
      'installed Flutter handler preserves previous handler and reports fatal error',
      () async {
        final backend = _FakeCrashReportingBackend();

        final service = CrashReportingService(
          backend: backend,
          platformSupported: true,
          platformLabel: 'android',
        );

        await service.initialize(_productionEnvironment());

        final originalHandler = FlutterError.onError;
        var previousHandlerCalled = false;

        FlutterError.onError = (_) {
          previousHandlerCalled = true;
        };

        try {
          service.installFlutterErrorHandler();

          final details = FlutterErrorDetails(
            exception: StateError('installed Flutter handler test'),
            stack: StackTrace.current,
          );

          FlutterError.onError?.call(details);

          await Future<void>.delayed(Duration.zero);

          expect(previousHandlerCalled, isTrue);

          expect(backend.flutterFatalErrors, hasLength(1));

          expect(backend.flutterFatalErrors.single, same(details));
        } finally {
          FlutterError.onError = originalHandler;
        }
      },
    );
    test('enabled service forwards Flutter fatal errors', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_productionEnvironment());

      final details = FlutterErrorDetails(
        exception: StateError('flutter fatal test'),
        stack: StackTrace.current,
        library: 'okan_test',
      );

      await service.recordFlutterFatalError(details);

      expect(backend.flutterFatalErrors, hasLength(1));

      expect(backend.flutterFatalErrors.single, same(details));
    });

    test('disabled service ignores Flutter fatal errors', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_developmentEnvironment());

      final details = FlutterErrorDetails(
        exception: StateError('must not be sent'),
        stack: StackTrace.current,
      );

      await service.recordFlutterFatalError(details);

      expect(backend.flutterFatalErrors, isEmpty);
    });

    test('enabled service forwards controlled errors and events', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_productionEnvironment());

      final error = StateError('test error');

      final stackTrace = StackTrace.current;

      await service.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: 'test_non_fatal',
      );

      await service.logEvent('test_event');

      expect(backend.recordedErrors, hasLength(1));

      final recorded = backend.recordedErrors.single;

      expect(recorded.error, same(error));

      expect(recorded.stackTrace, same(stackTrace));

      expect(recorded.fatal, isFalse);

      expect(recorded.reason, 'test_non_fatal');

      expect(backend.logs, <String>['test_event']);
    });

    test('disabled service never forwards errors or events', () async {
      final backend = _FakeCrashReportingBackend();

      final service = CrashReportingService(
        backend: backend,
        platformSupported: true,
        platformLabel: 'android',
      );

      await service.initialize(_developmentEnvironment());

      await service.recordError(
        StateError('must not be sent'),
        StackTrace.current,
        reason: 'disabled_test',
      );

      await service.logEvent('must_not_be_sent');

      expect(backend.recordedErrors, isEmpty);

      expect(backend.logs, isEmpty);
    });
  });
}

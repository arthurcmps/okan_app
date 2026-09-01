import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';

abstract class CrashReportingBackend {
  Future<void> setCollectionEnabled(bool enabled);

  Future<void> setCustomKey(String key, Object value);

  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  });

  Future<void> log(String message);
}

class FirebaseCrashReportingBackend implements CrashReportingBackend {
  FirebaseCrashReportingBackend({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics;

  final FirebaseCrashlytics? _crashlytics;

  FirebaseCrashlytics get _client =>
      _crashlytics ?? FirebaseCrashlytics.instance;

  @override
  Future<void> setCollectionEnabled(bool enabled) {
    return _client.setCrashlyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> setCustomKey(String key, Object value) {
    return _client.setCustomKey(key, value);
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) {
    return _client.recordFlutterFatalError(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) {
    return _client.recordError(error, stackTrace, fatal: fatal, reason: reason);
  }

  @override
  Future<void> log(String message) {
    return _client.log(message);
  }
}

class CrashReportingService {
  CrashReportingService({
    CrashReportingBackend? backend,
    bool? platformSupported,
    String? platformLabel,
  }) : _backend = backend ?? FirebaseCrashReportingBackend(),
       _platformSupported = platformSupported ?? _supportsCurrentPlatform(),
       _platformLabel = platformLabel ?? _currentPlatformLabel();

  static final CrashReportingService instance = CrashReportingService();

  final CrashReportingBackend _backend;
  final bool _platformSupported;
  final String _platformLabel;

  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> initialize(OkanEnvironmentConfig environment) async {
    _enabled = false;

    if (!_platformSupported) {
      _debugLog('Crash reporting unavailable on $_platformLabel.');
      return;
    }

    final shouldEnable = environment.enableCrashReporting;

    try {
      await _backend.setCollectionEnabled(shouldEnable);
    } catch (_) {
      _debugLog('Crash reporting collection configuration failed.');
      return;
    }

    _enabled = shouldEnable;

    if (!_enabled) {
      _debugLog('Crash reporting disabled for ${environment.label}.');
      return;
    }

    try {
      await _backend.setCustomKey('okan_environment', environment.label);

      await _backend.setCustomKey('okan_platform', _platformLabel);
    } catch (_) {
      _debugLog('Crash reporting metadata configuration failed.');
    }

    _debugLog('Crash reporting enabled for ${environment.label}.');
  }

  void installPlatformErrorHandler() {
    final previousHandler = PlatformDispatcher.instance.onError;

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      final previouslyHandled =
          previousHandler?.call(error, stackTrace) ?? false;

      if (!_enabled) {
        return previouslyHandled;
      }

      unawaited(
        recordError(
          error,
          stackTrace,
          fatal: true,
          reason: 'uncaught_async_error',
        ),
      );

      return true;
    };
  }

  void installFlutterErrorHandler() {
    final previousHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      if (previousHandler != null) {
        previousHandler(details);
      } else {
        FlutterError.presentError(details);
      }

      unawaited(recordFlutterFatalError(details));
    };
  }

  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    if (!_enabled) {
      return;
    }

    try {
      await _backend.recordFlutterFatalError(details);
    } catch (_) {
      _debugLog('Crash reporting recordFlutterFatalError failed.');
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    if (!_enabled) {
      return;
    }

    try {
      await _backend.recordError(
        error,
        stackTrace,
        fatal: fatal,
        reason: reason,
      );
    } catch (_) {
      _debugLog('Crash reporting recordError failed.');
    }
  }

  Future<void> logEvent(String event) async {
    if (!_enabled) {
      return;
    }

    try {
      await _backend.log(event);
    } catch (_) {
      _debugLog('Crash reporting log failed.');
    }
  }

  static bool _supportsCurrentPlatform() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  static String _currentPlatformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    return defaultTargetPlatform.name;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[OKAN OBS] $message');
    }
  }
}

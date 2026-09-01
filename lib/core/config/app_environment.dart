import 'package:flutter/services.dart';

const String productionFirebaseProjectId = 'app-academia-2914d';
const String stagingFirebaseProjectId = 'okan-staging-24829';
const String developmentFirebaseProjectId = 'demo-okan-dev';

enum OkanEnvironment { production, staging, development }

class OkanFirebaseConfig {
  const OkanFirebaseConfig({
    required this.projectId,
    required this.messagingSenderId,
    required this.storageBucket,
    required this.webApiKey,
    required this.webAppId,
    required this.webAuthDomain,
    required this.androidApiKey,
    required this.androidAppId,
    required this.iosApiKey,
    required this.iosAppId,
    required this.iosBundleId,
  });

  static const OkanFirebaseConfig stagingFromEnvironment = OkanFirebaseConfig(
    projectId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_PROJECT_ID',
      defaultValue: '',
    ),
    messagingSenderId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    ),
    storageBucket: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_STORAGE_BUCKET',
      defaultValue: '',
    ),
    webApiKey: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_WEB_API_KEY',
      defaultValue: '',
    ),
    webAppId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_WEB_APP_ID',
      defaultValue: '',
    ),
    webAuthDomain: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: '',
    ),
    androidApiKey: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_ANDROID_API_KEY',
      defaultValue: '',
    ),
    androidAppId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_ANDROID_APP_ID',
      defaultValue: '',
    ),
    iosApiKey: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_IOS_API_KEY',
      defaultValue: '',
    ),
    iosAppId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_IOS_APP_ID',
      defaultValue: '',
    ),
    iosBundleId: String.fromEnvironment(
      'OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID',
      defaultValue: '',
    ),
  );

  final String projectId;
  final String messagingSenderId;
  final String storageBucket;
  final String webApiKey;
  final String webAppId;
  final String webAuthDomain;
  final String androidApiKey;
  final String androidAppId;
  final String iosApiKey;
  final String iosAppId;
  final String iosBundleId;

  void validateForStaging() {
    final requiredValues = <String, String>{
      'OKAN_STAGING_FIREBASE_PROJECT_ID': projectId,
      'OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID': messagingSenderId,
      'OKAN_STAGING_FIREBASE_STORAGE_BUCKET': storageBucket,
      'OKAN_STAGING_FIREBASE_WEB_API_KEY': webApiKey,
      'OKAN_STAGING_FIREBASE_WEB_APP_ID': webAppId,
      'OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN': webAuthDomain,
      'OKAN_STAGING_FIREBASE_ANDROID_API_KEY': androidApiKey,
      'OKAN_STAGING_FIREBASE_ANDROID_APP_ID': androidAppId,
      'OKAN_STAGING_FIREBASE_IOS_API_KEY': iosApiKey,
      'OKAN_STAGING_FIREBASE_IOS_APP_ID': iosAppId,
      'OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID': iosBundleId,
    };

    final missing = requiredValues.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);

    if (missing.isNotEmpty) {
      throw StateError(
        'OKAN_ENV=staging exige configuração Firebase explícita. '
        'Valores ausentes: ${missing.join(', ')}.',
      );
    }

    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId != stagingFirebaseProjectId) {
      throw StateError(
        'OKAN_ENV=staging exige o projeto Firebase oficial '
        '$stagingFirebaseProjectId. Recebido: $normalizedProjectId.',
      );
    }
  }
}

class OkanEnvironmentConfig {
  const OkanEnvironmentConfig._({
    required this.environment,
    required this.emulatorHost,
    required this.firebaseConfig,
  });

  static const String _environmentValue = String.fromEnvironment(
    'OKAN_ENV',
    defaultValue: 'prod',
  );

  static const String _emulatorHostValue = String.fromEnvironment(
    'OKAN_EMULATOR_HOST',
    defaultValue: '',
  );

  final OkanEnvironment environment;
  final String? emulatorHost;
  final OkanFirebaseConfig? firebaseConfig;

  static OkanEnvironmentConfig get current {
    final resolvedEnvironment = resolveEnvironmentValue(
      flavor: appFlavor,
      environmentValue: _environmentValue,
      hasExplicitEnvironment: const bool.hasEnvironment('OKAN_ENV'),
    );

    return OkanEnvironmentConfig.fromValues(
      environment: resolvedEnvironment,
      emulatorHost: _emulatorHostValue,
      stagingFirebaseConfig: OkanFirebaseConfig.stagingFromEnvironment,
    );
  }

  static String resolveEnvironmentValue({
    required String? flavor,
    required String environmentValue,
    required bool hasExplicitEnvironment,
  }) {
    final normalizedFlavor = flavor?.trim().toLowerCase();

    if (normalizedFlavor == null || normalizedFlavor.isEmpty) {
      return environmentValue;
    }

    final flavorEnvironment = switch (normalizedFlavor) {
      'prod' => 'prod',
      'staging' => 'staging',
      'dev' => 'dev',
      _ => throw StateError(
        'Flavor Android inválido: `$normalizedFlavor`. '
        'Valores suportados: prod, staging ou dev.',
      ),
    };

    if (hasExplicitEnvironment) {
      final explicitEnvironment = _canonicalEnvironmentValue(environmentValue);

      if (explicitEnvironment != flavorEnvironment) {
        throw StateError(
          'Flavor `$normalizedFlavor` é incompatível com '
          'OKAN_ENV=`$environmentValue`. '
          'O flavor Android é a fonte de verdade do ambiente.',
        );
      }
    }

    return flavorEnvironment;
  }

  static String _canonicalEnvironmentValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return 'prod';

      case 'staging':
      case 'stage':
        return 'staging';

      case 'dev':
      case 'development':
        return 'dev';

      default:
        return value.trim().toLowerCase();
    }
  }

  factory OkanEnvironmentConfig.fromValues({
    required String environment,
    String emulatorHost = '',
    OkanFirebaseConfig? stagingFirebaseConfig,
  }) {
    switch (environment.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return const OkanEnvironmentConfig._(
          environment: OkanEnvironment.production,
          emulatorHost: null,
          firebaseConfig: null,
        );
      case 'staging':
      case 'stage':
        final config =
            stagingFirebaseConfig ?? OkanFirebaseConfig.stagingFromEnvironment;
        config.validateForStaging();
        return OkanEnvironmentConfig._(
          environment: OkanEnvironment.staging,
          emulatorHost: null,
          firebaseConfig: config,
        );
      case 'dev':
      case 'development':
        final normalizedHost = emulatorHost.trim();
        if (normalizedHost.isEmpty) {
          throw StateError(
            'OKAN_ENV=dev exige OKAN_EMULATOR_HOST. '
            'Use 10.0.2.2 no Android Emulator ou 127.0.0.1 no desktop/web. '
            'Em aparelho Android físico, use adb reverse nas portas dos '
            'emuladores e mantenha OKAN_EMULATOR_HOST=127.0.0.1.',
          );
        }
        return OkanEnvironmentConfig._(
          environment: OkanEnvironment.development,
          emulatorHost: normalizedHost,
          firebaseConfig: null,
        );
      default:
        throw ArgumentError.value(
          environment,
          'OKAN_ENV',
          'Ambiente inválido. Valores suportados: prod, staging ou dev.',
        );
    }
  }

  bool get isProduction => environment == OkanEnvironment.production;

  bool get isStaging => environment == OkanEnvironment.staging;

  bool get isDevelopment => environment == OkanEnvironment.development;

  bool get isNonProduction => !isProduction;

  bool get usesFirebaseEmulators => isDevelopment;

  bool get enableAppCheck => !isDevelopment;

  bool get enablePushNotifications => !isDevelopment;

  bool get enableCrashReporting => !isDevelopment;

  bool get enableExternalPayments => isProduction;

  bool get showEnvironmentBanner => isNonProduction;

  String get label {
    switch (environment) {
      case OkanEnvironment.production:
        return 'PROD';
      case OkanEnvironment.staging:
        return 'STAGING';
      case OkanEnvironment.development:
        return 'DEV • LOCAL';
    }
  }

  String get appTitle {
    switch (environment) {
      case OkanEnvironment.production:
        return 'Okan App';
      case OkanEnvironment.staging:
        return 'Okan App [STAGING]';
      case OkanEnvironment.development:
        return 'Okan App [DEV]';
    }
  }
}

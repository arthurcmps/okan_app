enum OkanEnvironment {
  production,
  development,
}

class OkanEnvironmentConfig {
  const OkanEnvironmentConfig._({
    required this.environment,
    required this.emulatorHost,
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

  static OkanEnvironmentConfig get current => OkanEnvironmentConfig.fromValues(
        environment: _environmentValue,
        emulatorHost: _emulatorHostValue,
      );

  factory OkanEnvironmentConfig.fromValues({
    required String environment,
    String emulatorHost = '',
  }) {
    switch (environment.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return const OkanEnvironmentConfig._(
          environment: OkanEnvironment.production,
          emulatorHost: null,
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
        );
      case 'staging':
      case 'stage':
        throw UnsupportedError(
          'OKAN_ENV=staging ainda não está configurado. '
          'Esse ambiente será entregue no OKAN-039.',
        );
      default:
        throw ArgumentError.value(
          environment,
          'OKAN_ENV',
          'Ambiente inválido. Valores suportados: prod ou dev.',
        );
    }
  }

  bool get isDevelopment => environment == OkanEnvironment.development;

  bool get usesFirebaseEmulators => isDevelopment;

  bool get enableAppCheck => !isDevelopment;

  bool get enablePushNotifications => !isDevelopment;

  bool get enableExternalPayments => !isDevelopment;

  String get label => isDevelopment ? 'DEV • LOCAL' : 'PROD';

  String get appTitle => isDevelopment ? 'Okan App [DEV]' : 'Okan App';
}

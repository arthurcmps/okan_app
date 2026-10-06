import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/services/client_compatibility_service.dart';

void main() {
  test('User v2 rollout contract matches app release metadata', () {
    expect(ClientCompatibilityInfo.schemaVersion, 2);
    expect(ClientCompatibilityInfo.appVersion, '1.0.3');
    expect(ClientCompatibilityInfo.buildNumber, 13);

    final pubspec = File('pubspec.yaml').readAsStringSync();

    const releaseVersion =
        '${ClientCompatibilityInfo.appVersion}+'
        '${ClientCompatibilityInfo.buildNumber}';

    expect(
      RegExp(
        '^version:\\s*${RegExp.escape(releaseVersion)}\\s*\$',
        multiLine: true,
      ).hasMatch(pubspec),
      isTrue,
      reason: 'A versão de compatibilidade deve corresponder ao pubspec.',
    );
  });
}

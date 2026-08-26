import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/services/client_compatibility_service.dart';

void main() {
  test('User v2 rollout contract matches app release metadata', () {
    expect(ClientCompatibilityInfo.schemaVersion, 2);
    expect(ClientCompatibilityInfo.appVersion, '1.0.1');
    expect(ClientCompatibilityInfo.buildNumber, 9);

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 1.0.1+9'));
  });
}

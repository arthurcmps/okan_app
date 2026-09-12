import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protege configuração local de staging contra commit', () {
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gitignore, contains('/config/*.local.json'));
    expect(gitignore, isNot(contains('/config/staging.example.json')));
  });

  test('modelo staging mantém contrato completo e falha sem as API keys', () {
    final decoded =
        jsonDecode(File('config/staging.example.json').readAsStringSync());

    expect(decoded, isA<Map<String, dynamic>>());
    final config = Map<String, dynamic>.from(decoded as Map);

    const requiredKeys = <String>{
      'OKAN_STAGING_FIREBASE_PROJECT_ID',
      'OKAN_STAGING_FIREBASE_MESSAGING_SENDER_ID',
      'OKAN_STAGING_FIREBASE_STORAGE_BUCKET',
      'OKAN_STAGING_FIREBASE_WEB_API_KEY',
      'OKAN_STAGING_FIREBASE_WEB_APP_ID',
      'OKAN_STAGING_FIREBASE_WEB_AUTH_DOMAIN',
      'OKAN_STAGING_FIREBASE_ANDROID_API_KEY',
      'OKAN_STAGING_FIREBASE_ANDROID_APP_ID',
      'OKAN_STAGING_FIREBASE_IOS_API_KEY',
      'OKAN_STAGING_FIREBASE_IOS_APP_ID',
      'OKAN_STAGING_FIREBASE_IOS_BUNDLE_ID',
    };

    expect(config.keys.toSet(), requiredKeys);
    expect(
      config['OKAN_STAGING_FIREBASE_PROJECT_ID'],
      'okan-staging-24829',
    );
    expect(
      config['OKAN_STAGING_FIREBASE_ANDROID_APP_ID'],
      '1:993246251446:android:c7e12e7f386b5c67cf1917',
    );
    expect(config['OKAN_STAGING_FIREBASE_WEB_API_KEY'], isEmpty);
    expect(config['OKAN_STAGING_FIREBASE_ANDROID_API_KEY'], isEmpty);
    expect(config['OKAN_STAGING_FIREBASE_IOS_API_KEY'], isEmpty);
  });
}

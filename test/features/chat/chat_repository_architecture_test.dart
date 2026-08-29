import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chat domain remains Firebase-free', () {
    final files = Directory('lib/features/chat/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')), reason: file.path);
      expect(source, isNot(contains('firebase_auth')), reason: file.path);
      expect(source, isNot(contains('FirebaseFirestore')), reason: file.path);
      expect(source, isNot(contains('FirebaseAuth')), reason: file.path);
    }
  });

  test('Chat presentation depends only on ChatRepository boundary', () {
    final source = File(
      'lib/features/chat/presentation/pages/chat_page.dart',
    ).readAsStringSync();
    expect(source, contains('ChatRepository'));
    expect(source, contains('currentUserId'));
    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('firebase_auth')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('FirebaseAuth.instance')));
  });

  test('legacy Chat path is compatibility export', () {
    final source = File(
      'lib/features/auth/presentation/pages/chat_page.dart',
    ).readAsStringSync().trim();
    expect(source, startsWith('export '));
  });
}

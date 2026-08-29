import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arena domain remains Firebase-free', () {
    final files = Directory('lib/features/arena/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')), reason: file.path);
      expect(source, isNot(contains('firebase_auth')), reason: file.path);
      expect(source, isNot(contains('Timestamp')), reason: file.path);
      expect(source, isNot(contains('FieldValue')), reason: file.path);
    }
  });

  test('Arena presentation delegates persistence to ArenaRepository', () {
    for (final path in <String>[
      'lib/features/arena/presentation/pages/arena_page.dart',
      'lib/features/arena/presentation/pages/duel_room_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ArenaRepository'), reason: path);
      expect(source, isNot(contains('cloud_firestore')), reason: path);
      expect(source, isNot(contains('firebase_auth')), reason: path);
      expect(source, isNot(contains('FirebaseFirestore')), reason: path);
      expect(source, isNot(contains('Timestamp')), reason: path);
      expect(source, isNot(contains('FieldValue')), reason: path);
    }
  });

  test('Arena Firebase paths live in data repository', () {
    final source = File(
      'lib/features/arena/data/repositories/firebase_arena_repository.dart',
    ).readAsStringSync();
    for (final path in <String>[
      "collection('friendships')",
      "collection('challenges')",
      "collection('posts')",
      "collection('comments')",
      "collection('workout_history')",
      "collection('notifications')",
    ]) {
      expect(source, contains(path), reason: path);
    }
    expect(source, contains('StorageService'));
  });

  test('legacy Arena path is compatibility export', () {
    final source = File(
      'lib/features/auth/presentation/pages/arena_page.dart',
    ).readAsStringSync().trim();
    expect(source, startsWith('export '));
  });
}

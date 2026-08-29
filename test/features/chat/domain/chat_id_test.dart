import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/chat/domain/chat_id.dart';

void main() {
  group('buildDeterministicChatId', () {
    test('returns the same id regardless of participant order', () {
      expect(
        buildDeterministicChatId('user-z', 'user-a'),
        buildDeterministicChatId('user-a', 'user-z'),
      );
    });

    test('sorts participant ids lexicographically', () {
      expect(
        buildDeterministicChatId('uid-b', 'uid-a'),
        'uid-a_uid-b',
      );
    });

    test('is stable across repeated calls', () {
      final first = buildDeterministicChatId('student-123', 'trainer-456');
      final second = buildDeterministicChatId('student-123', 'trainer-456');

      expect(second, first);
    });

    test('changes when the participant pair changes', () {
      expect(
        buildDeterministicChatId('user-a', 'user-b'),
        isNot(buildDeterministicChatId('user-a', 'user-c')),
      );
    });
  });
}

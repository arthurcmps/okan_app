import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/students/data/repositories/firebase_students_repository.dart';
import 'package:okan_app/features/students/domain/entities/student_invite_creation_result.dart';

void main() {
  group('normalizePremiumEntitlement', () {
    test('aceita apenas boolean true e string true normalizada', () {
      expect(normalizePremiumEntitlement(true), isTrue);
      expect(normalizePremiumEntitlement('true'), isTrue);
      expect(normalizePremiumEntitlement(' TRUE '), isTrue);
    });

    test('rejeita valores que nao representam premium', () {
      expect(normalizePremiumEntitlement(false), isFalse);
      expect(normalizePremiumEntitlement('false'), isFalse);
      expect(normalizePremiumEntitlement(1), isFalse);
      expect(normalizePremiumEntitlement(null), isFalse);
    });
  });

  group('StudentInviteCreationResult', () {
    test('normaliza flag alreadyPending retornada pela callable', () {
      expect(
        StudentInviteCreationResult.fromMap({
          'alreadyPending': true,
        }).alreadyPending,
        isTrue,
      );

      expect(
        StudentInviteCreationResult.fromMap({
          'alreadyPending': 'true',
        }).alreadyPending,
        isFalse,
      );

      expect(
        StudentInviteCreationResult.fromMap({}).alreadyPending,
        isFalse,
      );
    });
  });
}

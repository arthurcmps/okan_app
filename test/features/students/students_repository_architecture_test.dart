import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Students domain permanece livre de Firebase', () {
    const domainFiles = <String>[
      'lib/features/students/domain/entities/pending_student_invite.dart',
      'lib/features/students/domain/entities/student_invite_creation_result.dart',
      'lib/features/students/domain/entities/student_profile.dart',
      'lib/features/students/domain/entities/student_summary.dart',
      'lib/features/students/domain/repositories/students_repository.dart',
    ];

    for (final path in domainFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('Timestamp')));
      expect(source, isNot(contains('FieldValue')));
    }
  });

  test('presentation de Students usa StudentsRepository', () {
    const presentationFiles = <String>[
      'lib/features/students/presentation/pages/students_page.dart',
      'lib/features/students/presentation/pages/student_detail_page.dart',
    ];

    for (final path in presentationFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('StudentsRepository'));
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains("collection('users')")));
      expect(source, isNot(contains("collection('invites')")));
      expect(source, isNot(contains('FieldValue')));
      expect(source, isNot(contains('Timestamp')));
    }

    final detailSource = File(
      'lib/features/students/presentation/pages/student_detail_page.dart',
    ).readAsStringSync();
    expect(detailSource, contains('watchStudentProfile'));
    expect(detailSource, contains('unlinkStudent'));
  });

  test('caminhos antigos de Students sao exports de compatibilidade', () {
    final studentsSource = File(
      'lib/features/auth/presentation/pages/students_page.dart',
    ).readAsStringSync();
    final detailSource = File(
      'lib/features/auth/presentation/pages/student_detail_page.dart',
    ).readAsStringSync();

    expect(
      studentsSource.trim(),
      "export '../../../students/presentation/pages/students_page.dart';",
    );
    expect(
      detailSource.trim(),
      "export '../../../students/presentation/pages/student_detail_page.dart';",
    );
  });

  test('repository concentra infraestrutura de Students', () {
    final source = File(
      'lib/features/students/data/repositories/'
      'firebase_students_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('users')"));
    expect(source, contains("collection('invites')"));
    expect(source, contains('ProfessionalRelationshipsService'));
    expect(source, contains('watchStudentProfile'));
    expect(source, contains('Timestamp'));
  });
}

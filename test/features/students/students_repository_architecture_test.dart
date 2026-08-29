import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StudentsPage nao acessa Firestore diretamente', () {
    final source = File(
      'lib/features/auth/presentation/pages/students_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains("collection('users')")));
    expect(source, isNot(contains("collection('invites')")));
    expect(source, contains('StudentsRepository'));
    expect(source, contains('FirebaseStudentsRepository'));
  });

  test('repository concentra collections de Students', () {
    final source = File(
      'lib/features/students/data/repositories/'
      'firebase_students_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('users')"));
    expect(source, contains("collection('invites')"));
    expect(source, contains('ProfessionalRelationshipsService'));
  });
}

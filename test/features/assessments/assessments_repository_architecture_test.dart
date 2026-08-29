import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Assessments domain permanece livre de Firebase', () {
    const domainFiles = <String>[
      'lib/features/assessments/domain/entities/anamnese_record.dart',
      'lib/features/assessments/domain/entities/physical_assessment.dart',
      'lib/features/assessments/domain/entities/professor_note_state.dart',
      'lib/features/assessments/domain/repositories/assessments_repository.dart',
    ];

    for (final path in domainFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('firebase_auth')));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('FirebaseAuth')));
      expect(source, isNot(contains('Timestamp')));
      expect(source, isNot(contains('FieldValue')));
    }
  });

  test('presentation de Assessments usa repository boundary', () {
    const presentationFiles = <String>[
      'lib/features/assessments/presentation/pages/anamnese_tab.dart',
      'lib/features/assessments/presentation/pages/assessments_tab.dart',
      'lib/features/assessments/presentation/pages/evolution_charts_page.dart',
      'lib/features/assessments/presentation/widgets/professor_notes_widget.dart',
    ];

    for (final path in presentationFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AssessmentsRepository'));
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('firebase_auth')));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('FirebaseAuth')));
      expect(source, isNot(contains('DocumentSnapshot')));
      expect(source, isNot(contains('Timestamp')));
      expect(source, isNot(contains('FieldValue')));
    }
  });

  test('repository concentra paths persistidos do OKAN-033', () {
    final source = File(
      'lib/features/assessments/data/repositories/'
      'firebase_assessments_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('medical')"));
    expect(source, contains("doc('anamnese')"));
    expect(source, contains("collection('assessments')"));
    expect(source, contains("collection('private_notes')"));
    expect(source, contains('FieldValue.serverTimestamp'));
    expect(source, contains('FirebaseAuth'));
  });

  test('caminhos legados sao exports de compatibilidade', () {
    expect(
      File('lib/features/auth/presentation/pages/anamnese_tab.dart')
          .readAsStringSync()
          .trim(),
      "export '../../../assessments/presentation/pages/anamnese_tab.dart';",
    );
    expect(
      File('lib/features/auth/presentation/pages/assessments_tab.dart')
          .readAsStringSync()
          .trim(),
      "export '../../../assessments/presentation/pages/assessments_tab.dart';",
    );
    expect(
      File('lib/features/auth/presentation/pages/evolution_charts_page.dart')
          .readAsStringSync()
          .trim(),
      "export '../../../assessments/presentation/pages/evolution_charts_page.dart';",
    );
    expect(
      File('lib/core/widgets/professor_notes_widget.dart')
          .readAsStringSync()
          .trim(),
      "export '../../features/assessments/presentation/widgets/professor_notes_widget.dart';",
    );
  });
}

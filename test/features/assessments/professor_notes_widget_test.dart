import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/assessments/domain/entities/anamnese_record.dart';
import 'package:okan_app/features/assessments/domain/entities/physical_assessment.dart';
import 'package:okan_app/features/assessments/domain/entities/professor_note_state.dart';
import 'package:okan_app/features/assessments/domain/repositories/assessments_repository.dart';
import 'package:okan_app/features/assessments/presentation/widgets/professor_notes_widget.dart';

class _FakeAssessmentsRepository implements AssessmentsRepository {
  _FakeAssessmentsRepository({required this.noteStreamFactory});

  final Stream<ProfessorNoteState> Function(int call) noteStreamFactory;
  Completer<void>? saveCompleter;
  int watchCount = 0;
  int saveCount = 0;

  @override
  Stream<ProfessorNoteState> watchProfessorNote(String studentId) {
    watchCount++;
    return noteStreamFactory(watchCount);
  }

  @override
  Future<void> saveProfessorNote({
    required String studentId,
    required String text,
  }) async {
    saveCount++;
    await saveCompleter?.future;
  }

  @override
  Future<AnamneseRecord> loadAnamnese(String studentId) async {
    return AnamneseRecord.empty();
  }

  @override
  Stream<List<PhysicalAssessment>> watchAssessments(
    String studentId, {
    bool descending = true,
  }) {
    return Stream.value(const <PhysicalAssessment>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(_FakeAssessmentsRepository repository) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: ProfessorNotesWidget(
          studentId: 'student-1',
          repository: repository,
        ),
      ),
    );
  }

  testWidgets('shows a safe stream error and retries', (tester) async {
    final repository = _FakeAssessmentsRepository(
      noteStreamFactory: (call) => call == 1
          ? Stream<ProfessorNoteState>.error(StateError('uid=private'))
          : Stream.value(
              const ProfessorNoteState(isVisible: true, text: 'Evolução boa'),
            ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('professor-notes-error')),
      findsOneWidget,
    );
    expect(find.textContaining('uid=private'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('professor-notes-retry')));
    await tester.pumpAndSettle();

    expect(repository.watchCount, 2);
    expect(find.text('Anotações privadas do personal'), findsOneWidget);
    expect(find.text('Evolução boa'), findsOneWidget);
  });

  testWidgets('blocks editing and another save while saving', (tester) async {
    final repository = _FakeAssessmentsRepository(
      noteStreamFactory: (_) => Stream.value(
        const ProfessorNoteState(isVisible: true, text: 'Nota inicial'),
      ),
    )..saveCompleter = Completer<void>();

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('professor-notes-save')));
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(find.byKey(const ValueKey('professor-notes-save')), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    repository.saveCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Anotação atualizada!'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/assessments/domain/entities/anamnese_record.dart';
import 'package:okan_app/features/assessments/domain/entities/physical_assessment.dart';
import 'package:okan_app/features/assessments/domain/entities/professor_note_state.dart';
import 'package:okan_app/features/assessments/domain/repositories/assessments_repository.dart';
import 'package:okan_app/features/assessments/presentation/pages/anamnese_tab.dart';

class _FakeAssessmentsRepository implements AssessmentsRepository {
  _FakeAssessmentsRepository({required this.loadFactory});

  final Future<AnamneseRecord> Function(int call) loadFactory;
  Completer<void>? saveCompleter;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<AnamneseRecord> loadAnamnese(String studentId) {
    loadCount++;
    return loadFactory(loadCount);
  }

  @override
  Future<void> saveAnamnese({
    required String studentId,
    required Map<String, dynamic> values,
  }) async {
    saveCount++;
    await saveCompleter?.future;
  }

  @override
  Stream<ProfessorNoteState> watchProfessorNote(String studentId) {
    return Stream.value(const ProfessorNoteState.hidden());
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
  Widget testApp(
    _FakeAssessmentsRepository repository, {
    bool isEditable = true,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: AnamneseTab(
            studentId: 'student-1',
            isEditable: isEditable,
            repository: repository,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a safe load error and retries', (tester) async {
    final repository = _FakeAssessmentsRepository(
      loadFactory: (call) => call == 1
          ? Future<AnamneseRecord>.error(StateError('token=secret'))
          : Future.value(AnamneseRecord.empty()),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('anamnese-load-error')), findsOneWidget);
    expect(find.textContaining('token=secret'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.text('1. Objetivos'), findsOneWidget);
  });

  testWidgets('read-only mode does not expose the save action', (tester) async {
    final repository = _FakeAssessmentsRepository(
      loadFactory: (_) => Future.value(AnamneseRecord.empty()),
    );

    await tester.pumpWidget(testApp(repository, isEditable: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('anamnese-save')), findsNothing);
  });

  testWidgets('blocks duplicate saves while the request is running', (
    tester,
  ) async {
    final repository = _FakeAssessmentsRepository(
      loadFactory: (_) => Future.value(AnamneseRecord.empty()),
    )..saveCompleter = Completer<void>();

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('anamnese-save')));

    await tester.tap(find.byKey(const ValueKey('anamnese-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('anamnese-save')));
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('anamnese-save')),
          )
          .onPressed,
      isNull,
    );

    repository.saveCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Ficha salva com sucesso!'), findsOneWidget);
  });

  testWidgets('supports a narrow screen with text at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAssessmentsRepository(
      loadFactory: (_) => Future.value(AnamneseRecord.empty()),
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Objetivos'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

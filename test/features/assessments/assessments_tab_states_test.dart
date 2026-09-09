import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/assessments/domain/entities/physical_assessment.dart';
import 'package:okan_app/features/assessments/domain/entities/professor_note_state.dart';
import 'package:okan_app/features/assessments/domain/repositories/assessments_repository.dart';
import 'package:okan_app/features/assessments/presentation/pages/assessments_tab.dart';

class _FakeAssessmentsRepository implements AssessmentsRepository {
  _FakeAssessmentsRepository({
    required this.assessmentsStreamFactory,
    this.noteState = const ProfessorNoteState.hidden(),
  });

  final Stream<List<PhysicalAssessment>> Function() assessmentsStreamFactory;
  final ProfessorNoteState noteState;
  Completer<void>? saveCompleter;
  Object? saveError;
  int watchCount = 0;
  int saveCount = 0;

  @override
  Stream<List<PhysicalAssessment>> watchAssessments(
    String studentId, {
    bool descending = true,
  }) {
    watchCount++;
    return assessmentsStreamFactory();
  }

  @override
  Stream<ProfessorNoteState> watchProfessorNote(String studentId) {
    return Stream.value(noteState);
  }

  @override
  Future<void> addAssessment({
    required String studentId,
    required Map<String, dynamic> values,
  }) async {
    saveCount++;
    final error = saveError;
    if (error != null) throw error;
    await saveCompleter?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(
    _FakeAssessmentsRepository repository, {
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: AssessmentsTab(
          studentId: 'student-1',
          repository: repository,
        ),
      ),
    );
  }

  Future<void> openCompletedForm(
    WidgetTester tester,
    _FakeAssessmentsRepository repository,
  ) async {
    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova Avaliação'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '80');
    await tester.enterText(fields.at(1), '180');

    final formList = find.byType(ListView).last;
    for (var attempt = 0; attempt < 8; attempt++) {
      if (find.byKey(const ValueKey('assessment-save')).evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(formList, const Offset(0, -500));
      await tester.pump();
    }

    expect(find.byKey(const ValueKey('assessment-save')), findsOneWidget);
  }

  testWidgets('shows a safe list error and retries', (tester) async {
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () => Stream<List<PhysicalAssessment>>.error(
        StateError('technical firestore detail'),
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('assessments-error')), findsOneWidget);
    expect(
      find.text('Não foi possível carregar as avaliações'),
      findsOneWidget,
    );
    expect(find.textContaining('technical firestore detail'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(repository.watchCount, 2);
  });

  testWidgets('shows an instructive empty state', (tester) async {
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () =>
          Stream.value(const <PhysicalAssessment>[]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('assessments-empty')), findsOneWidget);
    expect(find.text('Nenhuma avaliação registrada'), findsOneWidget);
    expect(
      find.text('Use “Nova Avaliação” para registrar os primeiros dados.'),
      findsOneWidget,
    );
  });

  testWidgets('blocks duplicate assessment saves', (tester) async {
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () =>
          Stream.value(const <PhysicalAssessment>[]),
    )..saveCompleter = Completer<void>();

    await openCompletedForm(tester, repository);
    await tester.tap(find.byKey(const ValueKey('assessment-save')));
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('assessment-save')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.saveCompleter!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.saveCount, 1);
    expect(find.text('Avaliação salva!'), findsOneWidget);
  });

  testWidgets('keeps the form and hides technical save errors', (
    tester,
  ) async {
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () =>
          Stream.value(const <PhysicalAssessment>[]),
    )..saveError = StateError('token=secret');

    await openCompletedForm(tester, repository);
    await tester.tap(find.byKey(const ValueKey('assessment-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Não foi possível salvar a avaliação. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('token=secret'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('assessment-save')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('stacks paired fields on a narrow screen with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () =>
          Stream.value(const <PhysicalAssessment>[]),
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova Avaliação'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    final firstBottom = tester.getBottomLeft(fields.at(0)).dy;
    final secondTop = tester.getTopLeft(fields.at(1)).dy;

    expect(secondTop, greaterThanOrEqualTo(firstBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps assessment details with text at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAssessmentsRepository(
      assessmentsStreamFactory: () => Stream.value([
        PhysicalAssessment(
          id: 'assessment-1',
          date: DateTime(2026, 9, 9),
          values: const {
            'weight': 80,
            'height': 180,
            'generalRating': 'Ótimo',
            'bodyFatPercentage': 18,
            'armRightContracted': 35,
            'armLeftContracted': 34,
          },
        ),
      ]),
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09/09/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Braço Contraído'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('private note scrolls away with the assessment list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAssessmentsRepository(
      noteState: const ProfessorNoteState(
        isVisible: true,
        text: 'Anotação privada de teste',
      ),
      assessmentsStreamFactory: () => Stream.value(
        List.generate(
          8,
          (index) => PhysicalAssessment(
            id: 'assessment-$index',
            date: DateTime(2026, 9, 9 - index),
            values: const {
              'weight': 80,
              'height': 180,
              'generalRating': 'Bom',
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    final noteTitle = find.text('Anotações privadas do personal');
    expect(noteTitle, findsOneWidget);
    expect(tester.getTopLeft(noteTitle).dy, greaterThan(0));

    await tester.drag(
      find.byKey(const ValueKey('assessments-scroll')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();

    expect(noteTitle, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

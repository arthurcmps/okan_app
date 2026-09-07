import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_exercise.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_history.dart';
import 'package:okan_app/features/workouts/domain/repositories/workouts_repository.dart';
import 'package:okan_app/features/workouts/presentation/pages/workout_history_page.dart';

class _FakeWorkoutsRepository implements WorkoutsRepository {
  _FakeWorkoutsRepository(this.streamFactory);

  final Stream<List<WorkoutHistory>> Function() streamFactory;
  int watchCount = 0;

  @override
  Stream<List<WorkoutHistory>> watchWorkoutHistory(String studentId) {
    watchCount++;
    return streamFactory();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(WorkoutsRepository repository) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: WorkoutHistoryPage(
        studentId: 'student-1',
        studentName: 'Aluno Teste',
        repository: repository,
      ),
    );
  }

  testWidgets('shows a safe error and retries with a new stream', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository(
      () => Stream<List<WorkoutHistory>>.error(
        StateError('technical firestore detail'),
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('workout-history-error')),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível carregar o histórico'),
      findsOneWidget,
    );
    expect(find.textContaining('technical firestore detail'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(repository.watchCount, 2);
  });

  testWidgets('shows an instructive empty state', (tester) async {
    final repository = _FakeWorkoutsRepository(
      () => Stream.value(const <WorkoutHistory>[]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workout-history-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum treino finalizado ainda'), findsOneWidget);
    expect(
      find.text('Os treinos concluídos pelo aluno aparecerão aqui.'),
      findsOneWidget,
    );
  });

  testWidgets('preserves completed workout content', (tester) async {
    final history = WorkoutHistory(
      id: 'history-1',
      studentId: 'student-1',
      diaDaSemana: 'segunda',
      dataRealizacao: DateTime(2026, 9, 7, 18, 30),
      feedback: 'Treino concluído sem dor.',
      exercicios: [
        WorkoutExercise(
          id: 'exercise-1',
          nome: 'Remada curvada',
          series: '3',
          repeticoes: '12',
          concluido: true,
          carga: '20',
        ),
      ],
    );
    final repository = _FakeWorkoutsRepository(
      () => Stream.value([history]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('SEGUNDA - 07/09/2026'), findsOneWidget);
    expect(find.text('1/1 exercícios concluídos'), findsOneWidget);

    await tester.tap(find.textContaining('SEGUNDA - 07/09/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Remada curvada'), findsOneWidget);
    expect(find.text('20kg'), findsOneWidget);
    expect(find.text('Treino concluído sem dor.'), findsOneWidget);
  });
}

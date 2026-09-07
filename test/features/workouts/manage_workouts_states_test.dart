import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_model.dart';
import 'package:okan_app/features/workouts/domain/repositories/workouts_repository.dart';
import 'package:okan_app/features/workouts/presentation/pages/manage_workouts_page.dart';

class _FakeWorkoutsRepository implements WorkoutsRepository {
  _FakeWorkoutsRepository({
    required this.streamFactory,
    this.onDelete,
  });

  final Stream<List<WorkoutModel>> Function() streamFactory;
  final Future<void> Function(String workoutId)? onDelete;
  int watchCount = 0;

  @override
  Stream<List<WorkoutModel>> watchWorkoutModels() {
    watchCount++;
    return streamFactory();
  }

  @override
  Future<void> deleteWorkoutModel(String workoutId) async {
    await onDelete?.call(workoutId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(WorkoutsRepository repository) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ManageWorkoutsPage(repository: repository),
    );
  }

  testWidgets('distinguishes a loading failure from an empty list', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository(
      streamFactory: () => Stream<List<WorkoutModel>>.error(
        StateError('technical firestore detail'),
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('workout-models-error')),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível carregar seus modelos'),
      findsOneWidget,
    );
    expect(find.textContaining('technical firestore detail'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(repository.watchCount, 2);
  });

  testWidgets('shows an instructive empty state', (tester) async {
    final repository = _FakeWorkoutsRepository(
      streamFactory: () => Stream.value(const <WorkoutModel>[]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workout-models-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum modelo criado'), findsOneWidget);
    expect(
      find.text(
        'Crie um treino e salve-o como modelo para reutilizar depois.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('labels actions and blocks them while deleting', (tester) async {
    final deletion = Completer<void>();
    var deleteCount = 0;
    final workout = WorkoutModel(
      id: 'workout-1',
      nome: 'Treino de costas',
      grupoMuscular: 'Costas',
      exercicios: const [],
    );
    final repository = _FakeWorkoutsRepository(
      streamFactory: () => Stream.value([workout]),
      onDelete: (_) {
        deleteCount++;
        return deletion.future;
      },
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Editar Treino de costas'), findsOneWidget);
    expect(find.byTooltip('Excluir Treino de costas'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir Treino de costas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pump();

    expect(deleteCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final deleteButton = tester.widget<IconButton>(
      find.byTooltip('Excluir Treino de costas'),
    );
    expect(deleteButton.onPressed, isNull);

    deletion.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Treino excluído.'), findsOneWidget);
  });
}

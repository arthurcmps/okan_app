import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_exercise.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_model.dart';
import 'package:okan_app/features/workouts/domain/repositories/workouts_repository.dart';
import 'package:okan_app/features/workouts/presentation/pages/manage_workouts_page.dart';

class _FakeWorkoutsRepository implements WorkoutsRepository {
  _FakeWorkoutsRepository(this.models);

  final List<WorkoutModel> models;
  final List<String> deletedWorkoutIds = [];

  @override
  Stream<List<WorkoutModel>> watchWorkoutModels() => Stream.value(models);

  @override
  Stream<List<WorkoutCatalogExercise>> watchExerciseCatalog() {
    return Stream.value(const []);
  }

  @override
  Future<void> deleteWorkoutModel(String workoutId) async {
    deletedWorkoutIds.add(workoutId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const colors = ColorScheme.dark(
    primary: Color(0xFFCCFF00),
    onPrimary: Color(0xFF120E16),
    secondary: Color(0xFFE07A5F),
    surface: Color(0xFF1E1826),
    error: Color(0xFFFF453A),
  );

  ThemeData testTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colors,
      cardTheme: const CardThemeData(color: Color(0xFF1E1826)),
    );
  }

  testWidgets('uses semantic theme colors and preserves workout actions', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository([
      WorkoutModel(
        id: 'workout-1',
        nome: 'Treino A',
        grupoMuscular: 'Costas',
        exercicios: [
          WorkoutExercise(
            id: 'exercise-1',
            nome: 'Remada curvada',
            series: '3',
            repeticoes: '12',
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: ManageWorkoutsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(
      const ValueKey('manage-workout-card-workout-1'),
    );
    final card = tester.widget<Card>(cardFinder);
    expect(card.color, colors.surface);
    expect(find.text('Costas • 1 exercício'), findsOneWidget);

    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: cardFinder, matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, colors.primary.withOpacity(0.14));
    expect(avatar.foregroundColor, colors.primary);

    final editAction = find.byKey(
      const ValueKey('manage-workout-edit-workout-1'),
    );
    final deleteAction = find.byKey(
      const ValueKey('manage-workout-delete-workout-1'),
    );
    expect(find.byTooltip('Editar treino'), findsOneWidget);
    expect(find.byTooltip('Excluir treino'), findsOneWidget);
    expect(
      tester.widget<IconButton>(editAction).icon,
      isA<Icon>().having((icon) => icon.color, 'color', colors.primary),
    );
    expect(
      tester.widget<IconButton>(deleteAction).icon,
      isA<Icon>().having((icon) => icon.color, 'color', colors.error),
    );

    await tester.tap(editAction);
    await tester.pumpAndSettle();
    expect(find.text('Editar Treino'), findsOneWidget);
    expect(find.text('Treino A'), findsOneWidget);
    expect(find.text('Remada curvada'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Excluir Treino?'), findsOneWidget);
    expect(
      find.text("Tem certeza que deseja apagar 'Treino A'?"),
      findsOneWidget,
    );
    expect(repository.deletedWorkoutIds, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.deletedWorkoutIds, isEmpty);

    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repository.deletedWorkoutIds, ['workout-1']);
    expect(find.text('Treino excluído.'), findsOneWidget);
  });

  testWidgets('shows an instructive empty state without changing navigation', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository(const []);

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: ManageWorkoutsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manage-workouts-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum modelo criado.'), findsOneWidget);
    expect(
      find.text(
        'Quando você criar um modelo de treino, ele aparecerá aqui.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsNothing);
  });
}

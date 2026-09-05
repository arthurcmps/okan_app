import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_model.dart';
import 'package:okan_app/features/workouts/domain/repositories/workouts_repository.dart';
import 'package:okan_app/features/workouts/presentation/pages/create_workout_page.dart';

class _FakeWorkoutsRepository implements WorkoutsRepository {
  @override
  Stream<List<WorkoutCatalogExercise>> watchExerciseCatalog() {
    return Stream.value(const []);
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

  testWidgets('uses semantic theme colors without changing workout data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colors, brightness: Brightness.dark),
        home: CreateWorkoutPage(
          repository: _FakeWorkoutsRepository(),
          treinoId: 'workout-1',
          treinoDados: const {
            'nome': 'Treino A',
            'grupoMuscular': 'Costas',
            'exercicios': [
              {
                'id': 'exercise-1',
                'nome': 'Remada curvada',
                'series': '3',
                'repeticoes': '12',
                'observacao': 'Movimento controlado',
              },
            ],
          },
        ),
      ),
    );

    final addIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('create-workout-add-exercise')),
        matching: find.byType(Icon),
      ),
    );
    expect(addIcon.color, colors.primary);
    expect(find.byTooltip('Adicionar exercício'), findsOneWidget);

    final exerciseTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Remada curvada'),
        matching: find.byType(ListTile),
      ),
    );
    expect(exerciseTile.tileColor, colors.surface);

    final observation = tester.widget<Text>(
      find.text('Obs: Movimento controlado'),
    );
    expect(observation.style?.color, colors.secondary);

    final deleteAction = find.byTooltip('Remover exercício');
    final deleteIcon = tester.widget<Icon>(
      find.descendant(of: deleteAction, matching: find.byType(Icon)),
    );
    expect(deleteIcon.color, colors.error);

    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('create-workout-save')),
    );
    expect(
      saveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      colors.primary,
    );
    expect(
      saveButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      colors.onPrimary,
    );
    expect(find.text('ATUALIZAR TREINO'), findsOneWidget);
    expect(find.text('3x 12'), findsOneWidget);

    await tester.tap(deleteAction);
    await tester.pump();

    expect(find.text('Remada curvada'), findsNothing);
  });
}

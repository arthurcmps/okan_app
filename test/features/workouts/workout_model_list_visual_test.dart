import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_exercise.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_model.dart';
import 'package:okan_app/features/workouts/presentation/widgets/workout_model_list.dart';

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

  WorkoutModel model({
    String id = 'model-1',
    String nome = 'Treino completo de membros superiores',
    String grupoMuscular = 'Peito, costas e ombros',
    int exerciseCount = 2,
  }) {
    return WorkoutModel(
      id: id,
      nome: nome,
      grupoMuscular: grupoMuscular,
      exercicios: List.generate(
        exerciseCount,
        (index) => WorkoutExercise(
          id: 'exercise-$index',
          nome: 'Exercício $index',
          series: '3',
          repeticoes: '12',
        ),
      ),
    );
  }

  testWidgets('preserves complete content and callbacks', (tester) async {
    final editedIds = <String>[];
    final deletedIds = <String>[];
    final workout = model();

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: WorkoutModelList(
            workouts: [workout],
            deletingWorkoutIds: const {},
            onEdit: (item) => editedIds.add(item.id),
            onDelete: (item) => deletedIds.add(item.id),
          ),
        ),
      ),
    );

    expect(find.text(workout.nome), findsOneWidget);
    expect(find.text('Peito, costas e ombros • 2 exercícios'), findsOneWidget);

    final cardFinder = find.byKey(const ValueKey('workout-model-model-1'));
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: cardFinder, matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, colors.secondary.withOpacity(0.14));
    expect(avatar.foregroundColor, colors.secondary);

    await tester.tap(find.byKey(const ValueKey('edit-workout-model-1')));
    await tester.pump();
    expect(editedIds, ['model-1']);
    expect(deletedIds, isEmpty);

    await tester.tap(find.byKey(const ValueKey('delete-workout-model-1')));
    await tester.pump();
    expect(deletedIds, ['model-1']);
  });

  testWidgets('stacks actions without overflow on enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final workout = model();

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: WorkoutModelList(
                workouts: [workout],
                deletingWorkoutIds: const {},
                onEdit: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(workout.nome), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    expect(find.byType(Wrap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes deletion progress and disables both actions', (
    tester,
  ) async {
    final workout = model(exerciseCount: 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: WorkoutModelList(
            workouts: [workout],
            deletingWorkoutIds: const {'model-1'},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Peito, costas e ombros • 1 exercício'), findsOneWidget);
    expect(find.text('Excluindo...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('edit-workout-model-1')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('delete-workout-model-1')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('shows a single instructive empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: WorkoutModelList(
            workouts: const [],
            deletingWorkoutIds: const {},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('workout-models-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum modelo criado'), findsOneWidget);
    expect(
      find.text('Crie um treino e salve-o como modelo para reutilizar depois.'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}

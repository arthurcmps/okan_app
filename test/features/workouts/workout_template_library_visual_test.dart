import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/weekly_workout_plan.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_exercise.dart';
import 'package:okan_app/features/workouts/presentation/widgets/workout_template_library.dart';

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

  testWidgets('uses semantic colors and preserves import and delete callbacks', (
    tester,
  ) async {
    final template = WorkoutTemplate(
      id: 'template-1',
      nome: 'Costas completo',
      exercicios: [
        WorkoutExercise(
          id: 'exercise-1',
          nome: 'Remada curvada',
          series: '3',
          repeticoes: '12',
        ),
      ],
    );
    final importedIds = <String>[];
    final deletedIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: WorkoutTemplateLibrary(
            isLoading: false,
            templates: [template],
            onImport: (item) => importedIds.add(item.id),
            onDelete: (item) => deletedIds.add(item.id),
          ),
        ),
      ),
    );

    final cardFinder = find.byKey(
      const ValueKey('workout-template-template-1'),
    );
    final card = tester.widget<Card>(cardFinder);
    expect(card.color, colors.surface);
    expect(find.text('Costas completo'), findsOneWidget);
    expect(
      find.text('1 exercício • Toque para importar'),
      findsOneWidget,
    );

    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: cardFinder, matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, colors.secondary.withOpacity(0.14));
    expect(avatar.foregroundColor, colors.secondary);

    final deleteAction = find.byKey(
      const ValueKey('workout-template-delete-template-1'),
    );
    expect(find.byTooltip('Excluir template'), findsOneWidget);
    expect(
      tester.widget<IconButton>(deleteAction).icon,
      isA<Icon>().having((icon) => icon.color, 'color', colors.error),
    );

    await tester.tap(find.text('Costas completo'));
    await tester.pump();
    expect(importedIds, ['template-1']);
    expect(deletedIds, isEmpty);

    await tester.tap(deleteAction);
    await tester.pump();
    expect(deletedIds, ['template-1']);
  });

  testWidgets('shows an instructive empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: WorkoutTemplateLibrary(
            isLoading: false,
            templates: const [],
            onImport: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('workout-template-library-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum template salvo.'), findsOneWidget);
    expect(
      find.text('Salve um dia de treino para encontrá-lo aqui.'),
      findsOneWidget,
    );
  });
}

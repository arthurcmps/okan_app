import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/store/domain/entities/store_models.dart';
import 'package:okan_app/features/store/presentation/widgets/exercise_catalog_view.dart';

const _exercises = <StoreExercise>[
  StoreExercise(
    id: 'agachamento',
    name: 'Agachamento livre',
    group: 'Pernas',
  ),
  StoreExercise(
    id: 'supino',
    name: 'Supino reto',
    group: 'Peito',
    videoUrl: 'https://example.com/supino',
  ),
  StoreExercise(
    id: 'remada',
    name: 'Remada curvada',
    group: 'Costas',
  ),
];

Widget _catalog({
  bool canManage = true,
  ValueChanged<StoreExercise>? onEdit,
  ValueChanged<StoreExercise>? onDelete,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: ExerciseCatalogView(
          exercises: _exercises,
          canManage: canManage,
          onEdit: onEdit ?? (_) {},
          onDelete: onDelete ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('busca e filtro reduzem o catálogo sem perder os dados', (
    tester,
  ) async {
    await tester.pumpWidget(_catalog());

    await tester.enterText(
      find.byKey(const ValueKey('exercise-catalog-search')),
      'supino',
    );
    await tester.pump();

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Agachamento livre'), findsNothing);
    expect(find.text('1 de 3 exercícios'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('exercise-catalog-clear-filters')),
    );
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('exercise-catalog-group-filter')),
    );
    dropdown.onChanged?.call('Pernas');
    await tester.pump();

    expect(find.text('Agachamento livre'), findsOneWidget);
    expect(find.text('Supino reto'), findsNothing);
    expect(find.text('1 de 3 exercícios'), findsOneWidget);
  });

  testWidgets('ações administrativas identificam o exercício correto', (
    tester,
  ) async {
    StoreExercise? edited;
    StoreExercise? deleted;

    await tester.pumpWidget(
      _catalog(
        onEdit: (exercise) => edited = exercise,
        onDelete: (exercise) => deleted = exercise,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('exercise-catalog-edit-supino')),
    );
    await tester.tap(
      find.byKey(const ValueKey('exercise-catalog-delete-remada')),
    );

    expect(edited?.id, 'supino');
    expect(deleted?.id, 'remada');
  });

  testWidgets('catálogo cabe em tela estreita com fonte ampliada', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_catalog(textScale: 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('exercise-catalog-agachamento')),
      findsOneWidget,
    );
  });

  testWidgets('professor não recebe ações administrativas', (tester) async {
    await tester.pumpWidget(_catalog(canManage: false));

    expect(
      find.byKey(const ValueKey('exercise-catalog-read-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exercise-catalog-edit-agachamento')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('exercise-catalog-delete-agachamento')),
      findsNothing,
    );
  });
}

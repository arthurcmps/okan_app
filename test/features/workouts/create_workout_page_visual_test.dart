import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_exercise.dart';
import 'package:okan_app/features/workouts/domain/entities/workout_model.dart';
import 'package:okan_app/features/workouts/domain/repositories/workouts_repository.dart';
import 'package:okan_app/features/workouts/presentation/pages/create_workout_page.dart';

class _FakeWorkoutsRepository implements WorkoutsRepository {
  _FakeWorkoutsRepository({
    Stream<List<WorkoutCatalogExercise>> Function(int call)? catalogStreamFactory,
  }) : _catalogStreamFactory =
           catalogStreamFactory ??
           ((_) => Stream.value(const <WorkoutCatalogExercise>[]));

  final Stream<List<WorkoutCatalogExercise>> Function(int call)
      _catalogStreamFactory;
  Completer<void>? saveCompleter;
  Object? saveError;
  int catalogWatchCount = 0;
  int saveCount = 0;
  String? savedWorkoutId;
  String? savedName;
  String? savedGroup;
  String? savedPersonalId;
  List<WorkoutExercise> savedExercises = const [];

  @override
  Stream<List<WorkoutCatalogExercise>> watchExerciseCatalog() {
    catalogWatchCount++;
    return _catalogStreamFactory(catalogWatchCount);
  }

  @override
  Future<void> saveWorkoutModel({
    String? workoutId,
    required String nome,
    required String grupoMuscular,
    required List<WorkoutExercise> exercicios,
    required String? personalId,
  }) async {
    saveCount++;
    savedWorkoutId = workoutId;
    savedName = nome;
    savedGroup = grupoMuscular;
    savedPersonalId = personalId;
    savedExercises = List<WorkoutExercise>.from(exercicios);
    final error = saveError;
    if (error != null) throw error;
    await saveCompleter?.future;
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

  Widget testApp(
    _FakeWorkoutsRepository repository, {
    String? workoutId,
    Map<String, dynamic>? workoutData,
  }) {
    return MaterialApp(
      theme: ThemeData(colorScheme: colors, brightness: Brightness.dark),
      home: CreateWorkoutPage(
        repository: repository,
        treinoId: workoutId,
        treinoDados: workoutData,
        personalId: 'professor-1',
      ),
    );
  }

  testWidgets('uses semantic theme colors without changing workout data', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        _FakeWorkoutsRepository(),
        workoutId: 'workout-1',
        workoutData: const {
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
    expect(find.byKey(const ValueKey('create-workout-empty')), findsOneWidget);
  });

  testWidgets('catalog error is safe and retries with a new stream', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository(
      catalogStreamFactory: (call) => call == 1
          ? Stream<List<WorkoutCatalogExercise>>.error(
              StateError('token=secret'),
            )
          : Stream.value([
              WorkoutCatalogExercise(
                nome: 'Agachamento livre',
                grupo: 'Pernas',
                videoUrl: '',
              ),
            ]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.tap(
      find.byKey(const ValueKey('create-workout-add-exercise')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-workout-catalog-error')),
      findsOneWidget,
    );
    expect(find.textContaining('token=secret'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.catalogWatchCount, 2);
    expect(find.text('Agachamento livre'), findsOneWidget);
  });

  testWidgets('adds a catalog exercise and blocks duplicate saves', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository(
      catalogStreamFactory: (_) => Stream.value([
        WorkoutCatalogExercise(
          nome: 'Agachamento livre',
          grupo: 'Pernas',
          videoUrl: 'https://example.com/agachamento',
        ),
      ]),
    )..saveCompleter = Completer<void>();

    await tester.pumpWidget(testApp(repository));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do Treino'),
      'Treino de pernas',
    );
    await tester.tap(
      find.byKey(const ValueKey('create-workout-add-exercise')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agachamento livre'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Agachamento livre'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-workout-save')));
    await tester.tap(find.byKey(const ValueKey('create-workout-save')));
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(repository.savedName, 'Treino de pernas');
    expect(repository.savedPersonalId, 'professor-1');
    expect(repository.savedExercises.single.nome, 'Agachamento livre');
    expect(repository.savedExercises.single.series, '3');
    expect(repository.savedExercises.single.repeticoes, '12');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.saveCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reorders, removes only one exercise and preserves edit id', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository()
      ..saveCompleter = Completer<void>();

    await tester.pumpWidget(
      testApp(
        repository,
        workoutId: 'workout-1',
        workoutData: const {
          'nome': 'Treino completo',
          'grupoMuscular': 'Corpo inteiro',
          'exercicios': [
            {'id': 'a', 'nome': 'Exercício A', 'series': '3', 'repeticoes': '8'},
            {
              'id': 'b',
              'nome': 'Exercício B',
              'series': '3',
              'repeticoes': '10',
            },
            {
              'id': 'c',
              'nome': 'Exercício C',
              'series': '3',
              'repeticoes': '12',
            },
          ],
        },
      ),
    );

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder(0, 3);
    await tester.pump();
    await tester.tap(find.byTooltip('Remover exercício').at(1));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-workout-save')));
    await tester.pump();

    expect(repository.savedWorkoutId, 'workout-1');
    expect(
      repository.savedExercises.map((exercise) => exercise.id),
      orderedEquals(['b', 'a']),
    );
    expect(find.text('Exercício C'), findsNothing);
    expect(find.text('Exercício A'), findsOneWidget);
    expect(find.text('Exercício B'), findsOneWidget);

    repository.saveCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the page and hides technical save failures', (
    tester,
  ) async {
    final repository = _FakeWorkoutsRepository()
      ..saveError = StateError('permission-denied uid=private');

    await tester.pumpWidget(
      testApp(
        repository,
        workoutId: 'workout-1',
        workoutData: const {
          'nome': 'Treino A',
          'grupoMuscular': 'Costas',
          'exercicios': [
            {'id': 'a', 'nome': 'Remada', 'series': '3', 'repeticoes': '12'},
          ],
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('create-workout-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar o treino. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(find.textContaining('uid=private'), findsNothing);
    expect(find.text('Editar Treino'), findsOneWidget);
  });
}

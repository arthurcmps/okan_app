import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/store/domain/entities/store_models.dart';
import 'package:okan_app/features/store/domain/repositories/store_repository.dart';
import 'package:okan_app/features/store/presentation/pages/library_admin_page.dart';

class _FakeStoreRepository implements StoreRepository {
  bool failExerciseSave = false;
  bool failTemplateSave = false;
  int exerciseSaveCalls = 0;
  int templateSaveCalls = 0;
  int exerciseDeleteCalls = 0;

  final exercises = const <StoreExercise>[
    StoreExercise(
      id: 'agachamento',
      name: 'Agachamento livre',
      group: 'Pernas',
    ),
  ];

  @override
  String? get currentUserId => 'professor-1';

  @override
  Future<void> saveExercise({
    String? exerciseId,
    required String name,
    required String group,
    required String videoUrl,
  }) async {
    exerciseSaveCalls++;
    if (failExerciseSave) throw StateError('permission-denied');
  }

  @override
  Stream<List<StoreExercise>> watchExercises() => Stream.value(exercises);

  @override
  Stream<List<StoreTemplate>> watchCurrentProfessionalTemplates() =>
      Stream.value(const <StoreTemplate>[]);

  @override
  Future<void> saveProfessionalTemplate({
    String? templateId,
    required String name,
    required List<Map<String, dynamic>> exercises,
  }) async {
    templateSaveCalls++;
    if (failTemplateSave) throw StateError('permission-denied');
  }

  @override
  Future<StoreUserState> loadCurrentUser() => throw UnimplementedError();

  @override
  Stream<StoreUserState> watchCurrentUser() => throw UnimplementedError();

  @override
  Stream<List<StoreTemplate>> watchPremiumTemplates() =>
      throw UnimplementedError();

  @override
  Future<void> acquireFreeTemplate(String templateId) =>
      throw UnimplementedError();

  @override
  Future<PixPaymentData> createPixPayment(String templateId) =>
      throw UnimplementedError();

  @override
  Future<CardPaymentResult> createCardPayment(CardPaymentRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> deleteExercise(String exerciseId) async {
    exerciseDeleteCalls++;
  }

  @override
  Stream<List<StoreTemplate>> watchSystemTemplates() =>
      throw UnimplementedError();

  @override
  Future<void> saveSystemTemplate({
    String? templateId,
    required String name,
    required Map<String, List<Map<String, dynamic>>> sheets,
    required List<String> tags,
    required double price,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteTemplate(String templateId) =>
      throw UnimplementedError();
}

Widget _app(
  StoreRepository repository, {
  bool canManageCatalog = false,
  bool catalogOnly = false,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: LibraryAdminPage(
      repository: repository,
      canManageExerciseCatalog: canManageCatalog,
      catalogOnly: catalogOnly,
    ),
  );
}

void main() {
  testWidgets('professor usa catálogo sem controles administrativos', (
    tester,
  ) async {
    final repository = _FakeStoreRepository();

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('exercise-catalog-read-only')),
      findsOneWidget,
    );
    expect(find.text('Agachamento livre'), findsOneWidget);
    expect(find.text('Novo exercício'), findsNothing);
    expect(find.byTooltip('Editar Agachamento livre'), findsNothing);
    expect(find.byTooltip('Excluir Agachamento livre'), findsNothing);

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();

    expect(find.text('Novo template'), findsOneWidget);
  });

  testWidgets('falha administrativa mantém diálogo e mostra erro seguro', (
    tester,
  ) async {
    final repository = _FakeStoreRepository()..failExerciseSave = true;

    await tester.pumpWidget(_app(repository, canManageCatalog: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo exercício'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do Exercício'),
      'Supino reto',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Grupo Muscular'),
      'Peito',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(repository.exerciseSaveCalls, 1);
    expect(find.text('Novo Exercício'), findsOneWidget);
    expect(
      find.text('Não foi possível salvar o exercício. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
  });

  testWidgets('super admin tem catálogo explícito sem aba de templates', (
    tester,
  ) async {
    final repository = _FakeStoreRepository();

    await tester.pumpWidget(
      _app(repository, canManageCatalog: true, catalogOnly: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrar catálogo'), findsOneWidget);
    expect(find.text('Novo exercício'), findsOneWidget);
    expect(find.text('Templates'), findsNothing);
    expect(
      find.byKey(const ValueKey('exercise-catalog-admin')),
      findsOneWidget,
    );
  });

  testWidgets('cadastro bloqueia nome duplicado antes do repositório', (
    tester,
  ) async {
    final repository = _FakeStoreRepository();

    await tester.pumpWidget(_app(repository, canManageCatalog: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo exercício'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do Exercício'),
      '  AGACHAMENTO   LIVRE ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Grupo Muscular'),
      'Pernas',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(repository.exerciseSaveCalls, 0);
    expect(
      find.text('Já existe um exercício com esse nome.'),
      findsOneWidget,
    );
  });

  testWidgets('falha ao salvar template não fecha o construtor', (
    tester,
  ) async {
    final repository = _FakeStoreRepository()..failTemplateSave = true;

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo template'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do Treino'),
      'Treino de pernas',
    );
    await tester.tap(find.text('Adicionar Exercício'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agachamento livre'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salvar template'));
    await tester.pumpAndSettle();

    expect(repository.templateSaveCalls, 1);
    expect(find.text('Criar Novo Template'), findsOneWidget);
    expect(
      find.text('Não foi possível salvar o template. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
  });
}

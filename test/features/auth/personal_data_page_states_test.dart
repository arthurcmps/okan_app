import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/personal_data_page.dart';

void main() {
  Widget testApp({
    required PersonalDataLoader loader,
    PersonalDataSaver? saver,
    PasswordUpdater? passwordUpdater,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: PersonalDataPage(
            uid: 'synthetic-user',
            loadData: loader,
            saveData: saver ?? (_, _) async {},
            updatePassword: passwordUpdater ?? (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets('announces loading and renders the loaded values', (
    tester,
  ) async {
    final completer = Completer<PersonalDataValue>();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(testApp(loader: (_) => completer.future));

    expect(
      find.bySemanticsLabel('Carregando informações pessoais'),
      findsOneWidget,
    );

    completer.complete(
      PersonalDataValue(
        gender: 'Homem Cis',
        birthDate: DateTime(1993, 8, 11),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homem Cis'), findsOneWidget);
    expect(find.text('11/08/1993'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows a recoverable state and retries loading', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      testApp(
        loader: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return const PersonalDataValue(gender: 'Não-Binário');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar suas informações'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Não-Binário'), findsOneWidget);
  });

  testWidgets('does not expose technical details when saving fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        loader: (_) async => const PersonalDataValue(),
        saver: (_, _) async => throw StateError('private-token'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SALVAR ALTERAÇÕES'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível salvar suas informações. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private-token'), findsNothing);
  });

  testWidgets('password dialog supports a small screen and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        loader: (_) async => const PersonalDataValue(),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Alterar minha senha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alterar minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Alterar senha'), findsOneWidget);
    expect(find.text('Nova senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/widgets/okan_async_state.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }

  testWidgets('loading state announces its context', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      testApp(
        const OkanLoadingState(label: 'Carregando modelos de treino'),
      ),
    );

    expect(
      find.bySemanticsLabel('Carregando modelos de treino'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('message state explains the error and exposes retry', (
    tester,
  ) async {
    var retryCount = 0;

    await tester.pumpWidget(
      testApp(
        OkanMessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar',
          description: 'Verifique sua conexão e tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: () => retryCount++,
          isError: true,
          announce: true,
        ),
      ),
    );

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(
      find.text('Verifique sua conexão e tente novamente.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('message state supports small screens and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const Scaffold(
              body: OkanMessageState(
                icon: Icons.fitness_center_outlined,
                title: 'Nenhum modelo criado',
                description:
                    'Crie um treino e salve-o como modelo para reutilizar depois.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nenhum modelo criado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

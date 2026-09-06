import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'showOnboarding': true});
  });

  testWidgets('skip stores the existing preference and completes', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(onCompleted: () => completed = true),
      ),
    );

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('showOnboarding'), isFalse);
    expect(completed, isTrue);
  });

  testWidgets('next reaches all three messages and completes', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(onCompleted: () => completed = true),
      ),
    );

    expect(find.text('Conceito Sankofa'), findsOneWidget);

    await tester.tap(find.text('PRÓXIMO'));
    await tester.pumpAndSettle();
    expect(find.text('Treinos Inteligentes'), findsOneWidget);

    await tester.tap(find.text('PRÓXIMO'));
    await tester.pumpAndSettle();
    expect(find.text('Sua Melhor Versão'), findsOneWidget);
    expect(find.text('Pular'), findsNothing);

    await tester.tap(find.text('COMEÇAR AGORA'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('showOnboarding'), isFalse);
    expect(completed, isTrue);
  });

  testWidgets('page indicator exposes its current position', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onCompleted: () {})),
    );

    expect(find.bySemanticsLabel('Página 1 de 3'), findsOneWidget);

    await tester.tap(find.text('PRÓXIMO'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Página 2 de 3'), findsOneWidget);
  });

  testWidgets('small screen and enlarged text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: OnboardingPage(onCompleted: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Conceito Sankofa'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    expect(find.text('PRÓXIMO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

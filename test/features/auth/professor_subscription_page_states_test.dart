import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/professor_subscription_page.dart';

void main() {
  Widget testApp({
    required SubscriptionDataStream subscriptionDataStream,
    SubscriptionCancellationRequester? requestCancellation,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ProfessorSubscriptionPage(
            userId: 'synthetic-professor',
            subscriptionDataStream: subscriptionDataStream,
            requestCancellation: requestCancellation,
          ),
        ),
      ),
    );
  }

  testWidgets('announces loading and renders the current plan', (tester) async {
    final controller = StreamController<Map<String, dynamic>?>();
    final semantics = tester.ensureSemantics();
    addTearDown(controller.close);

    await tester.pumpWidget(
      testApp(subscriptionDataStream: (_) => controller.stream),
    );

    expect(find.bySemanticsLabel('Carregando planos'), findsOneWidget);

    controller.add(<String, dynamic>{'isPremium': false});
    await tester.pumpAndSettle();

    expect(find.text('Plano Base'), findsOneWidget);
    expect(find.text('SEU PLANO ATUAL'), findsOneWidget);
    expect(find.text('Mestre Sankofa'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows a recoverable state and retries loading plans', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      testApp(
        subscriptionDataStream: (_) {
          attempts++;
          if (attempts == 1) {
            return Stream<Map<String, dynamic>?>.error(
              StateError('private-token'),
            );
          }
          return Stream.value(<String, dynamic>{'isPremium': true});
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar seus planos'),
      findsOneWidget,
    );
    expect(find.textContaining('private-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('PLANO ATIVO'), findsOneWidget);
  });

  testWidgets('does not expose technical details when cancellation fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        subscriptionDataStream: (_) =>
            Stream.value(<String, dynamic>{'isPremium': true}),
        requestCancellation: () async => throw StateError('private-token'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('REBAIXAR PLANO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REBAIXAR PLANO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível solicitar o cancelamento. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private-token'), findsNothing);
  });

  testWidgets('supports a small screen and 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        subscriptionDataStream: (_) =>
            Stream.value(<String, dynamic>{'isPremium': true}),
        requestCancellation: () async =>
            const SubscriptionCancellationResult(alreadyInactive: false),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plano Base'), findsOneWidget);
    expect(find.text('Mestre Sankofa'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('REBAIXAR PLANO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REBAIXAR PLANO'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitar cancelamento?'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/auth_check.dart';

class _FakeUser extends Fake implements User {}

void main() {
  Widget testApp({
    required Stream<User?> authStateChanges,
    bool showOnboarding = false,
  }) {
    return MaterialApp(
      home: AuthCheck(
        showOnboarding: showOnboarding,
        authStateChanges: authStateChanges,
        homeBuilder: (_) => const Text('home'),
        loginBuilder: (_) => const Text('login'),
        onboardingBuilder: (_) => const Text('onboarding'),
      ),
    );
  }

  testWidgets('keeps listening and leaves home when session becomes null', (
    tester,
  ) async {
    final controller = StreamController<User?>();
    addTearDown(controller.close);

    await tester.pumpWidget(testApp(authStateChanges: controller.stream));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add(_FakeUser());
    await tester.pump();
    expect(find.text('home'), findsOneWidget);

    controller.add(null);
    await tester.pump();
    expect(find.text('login'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('preserves onboarding for the first unauthenticated access', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        authStateChanges: Stream<User?>.value(null),
        showOnboarding: true,
      ),
    );
    await tester.pump();

    expect(find.text('onboarding'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}

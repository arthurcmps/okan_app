import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/widgets/home_action_cards.dart';

void main() {
  testWidgets('workout card preserves the complete first exercise name', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeWorkoutCard(
            dayLabel: 'SEGUNDA-FEIRA',
            exerciseCount: 4,
            firstExerciseName: 'Supino inclinado com halteres',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('4 exercícios'), findsOneWidget);
    expect(find.text('Supino inclinado com halteres'), findsOneWidget);
    expect(find.text('VER TREINO'), findsOneWidget);
    expect(find.textContaining('Foco:'), findsNothing);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('quick actions stack on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: HomeQuickActionsGrid(
              actions: [
                SizedBox(key: Key('metas'), height: 80),
                SizedBox(key: Key('semana'), height: 80),
              ],
            ),
          ),
        ),
      ),
    );

    final metas = tester.getRect(find.byKey(const Key('metas')));
    final semana = tester.getRect(find.byKey(const Key('semana')));

    expect(semana.top, greaterThan(metas.bottom));
    expect(metas.width, semana.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions share a row when enough width is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: HomeQuickActionsGrid(
              actions: [
                SizedBox(key: Key('metas'), height: 80),
                SizedBox(key: Key('semana'), height: 80),
              ],
            ),
          ),
        ),
      ),
    );

    final metas = tester.getRect(find.byKey(const Key('metas')));
    final semana = tester.getRect(find.byKey(const Key('semana')));

    expect(metas.top, semana.top);
    expect(semana.left, greaterThan(metas.right));
    expect(metas.width, semana.width);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/core/widgets/user_avatar.dart';

void main() {
  const colors = ColorScheme.dark(
    primary: Color(0xFFCCFF00),
    secondary: Color(0xFFE07A5F),
    surfaceContainerHighest: Color(0xFF2A2233),
    secondaryContainer: Color(0xFF4A241C),
    onSecondaryContainer: Color(0xFFFFDAD0),
  );

  Widget testApp({
    String? photoUrl,
    String name = 'Arthur',
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: colors,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: Center(
          child: UserAvatar(
            photoUrl: photoUrl,
            name: name,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Finder semanticsWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == label,
    );
  }

  testWidgets('uses a trimmed initial and semantic theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(name: '  arthur  '));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final initial = tester.widget<Text>(find.text('A'));

    expect(avatar.backgroundColor, colors.surfaceContainerHighest);
    expect(initial.style?.color, colors.onSecondaryContainer);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('describes a static avatar as an image', (tester) async {
    await tester.pumpWidget(testApp());

    final semantics = tester.widget<Semantics>(
      semanticsWithLabel('Avatar de Arthur'),
    );

    expect(semantics.properties.image, isTrue);
    expect(semantics.properties.button, isNull);
  });

  testWidgets('exposes and executes the profile action', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      testApp(onTap: () => tapCount++),
    );

    final semantics = tester.widget<Semantics>(
      semanticsWithLabel('Abrir perfil de Arthur'),
    );

    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.onTap, isNotNull);
    expect(find.byTooltip('Abrir perfil de Arthur'), findsOneWidget);

    await tester.tap(find.byType(InkResponse));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('uses a safe fallback when the name is blank', (tester) async {
    await tester.pumpWidget(testApp(name: '   '));

    expect(find.text('?'), findsOneWidget);
    expect(semanticsWithLabel('Avatar de usuário'), findsOneWidget);
  });
}

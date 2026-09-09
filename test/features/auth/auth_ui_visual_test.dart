import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/widgets/auth_ui.dart';

void main() {
  testWidgets('password visibility controls are independent', (tester) async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    addTearDown(passwordController.dispose);
    addTearDown(confirmationController.dispose);

    var passwordVisible = false;
    var confirmationVisible = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AuthPasswordField(
                  fieldKey: const Key('password'),
                  toggleKey: const Key('password-toggle'),
                  controller: passwordController,
                  label: 'Senha',
                  passwordVisible: passwordVisible,
                  onToggleVisibility: () => setState(
                    () => passwordVisible = !passwordVisible,
                  ),
                ),
                AuthPasswordField(
                  fieldKey: const Key('confirmation'),
                  toggleKey: const Key('confirmation-toggle'),
                  controller: confirmationController,
                  label: 'Confirmar senha',
                  passwordVisible: confirmationVisible,
                  onToggleVisibility: () => setState(
                    () => confirmationVisible = !confirmationVisible,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    TextFormField passwordField() => tester.widget(
      find.byKey(const Key('password')),
    );
    TextFormField confirmationField() => tester.widget(
      find.byKey(const Key('confirmation')),
    );

    expect(passwordField().obscureText, isTrue);
    expect(confirmationField().obscureText, isTrue);

    await tester.tap(find.byKey(const Key('password-toggle')));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(confirmationField().obscureText, isTrue);
    expect(find.byTooltip('Ocultar Senha'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation-toggle')));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(confirmationField().obscureText, isFalse);
  });

  testWidgets('feedback is announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthFeedbackBanner(message: 'E-mail ou senha incorretos.'),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('E-mail ou senha incorretos.'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('auth frame remains scrollable with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: AuthPageFrame(
                child: Column(
                  children: [
                    const Text('Acesse sua conta'),
                    for (var index = 0; index < 6; index++)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: TextField(
                          decoration: InputDecoration(labelText: 'Campo'),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const FilledButton(
                      onPressed: null,
                      child: Text('CONTINUAR'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('CONTINUAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('auth contracts remain present in their original pages', () {
    final login = File(
      'lib/features/auth/presentation/pages/login_page.dart',
    ).readAsStringSync();
    final register = File(
      'lib/features/auth/presentation/pages/register_page.dart',
    ).readAsStringSync();
    final verifyEmail = File(
      'lib/features/auth/presentation/pages/verify_email_page.dart',
    ).readAsStringSync();

    expect(login, contains('_authService.loginUsuario('));
    expect(login, contains('_authService.entrarComGoogle()'));
    expect(login, contains('sendPasswordResetEmail(email: email)'));
    expect(register, contains('.createUserWithEmailAndPassword('));
    expect(register, contains("collection('users').doc(uid).set"));
    expect(register, contains("'schemaVersion': UserModel.currentSchemaVersion"));
    expect(register, contains("'role': _selectedRole"));
    expect(register, contains("'memberType': memberType"));
    expect(register, contains('await user.sendEmailVerification()'));
    expect(verifyEmail, contains('sendEmailVerification()'));

    expect(register, isNot(contains(r'Text("Erro: $e")')));
    expect(verifyEmail, isNot(contains(r'Text("Erro: $e")')));
  });
}

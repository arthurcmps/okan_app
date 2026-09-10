import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/profile_page.dart';

void main() {
  final profileData = <String, dynamic>{
    'schemaVersion': 2,
    'name': 'Pessoa Sintética',
    'email': 'synthetic@example.com',
    'role': 'professor',
    'memberType': 'professor',
    'birthDate': DateTime(1993, 8, 11),
  };

  Widget testApp({
    required ProfileDataStream profileDataStream,
    ProfileImagePicker? imagePicker,
    ProfilePhotoUploader? photoUploader,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ProfilePage(
            userId: 'synthetic-user',
            profileDataStream: profileDataStream,
            imagePicker: imagePicker,
            photoUploader: photoUploader,
            signOut: () async {},
            anamneseBuilder: (_) => const SizedBox.shrink(),
            assessmentsBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  testWidgets('announces loading and renders the loaded profile', (
    tester,
  ) async {
    final controller = StreamController<Map<String, dynamic>?>();
    final semantics = tester.ensureSemantics();
    addTearDown(controller.close);

    await tester.pumpWidget(
      testApp(profileDataStream: (_) => controller.stream),
    );

    expect(find.bySemanticsLabel('Carregando perfil'), findsOneWidget);

    controller.add(profileData);
    await tester.pumpAndSettle();

    expect(find.text('Pessoa Sintética'), findsOneWidget);
    expect(find.text('PERSONAL TRAINER'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Alterar foto do perfil'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows a recoverable state and retries the profile stream', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      testApp(
        profileDataStream: (_) {
          attempts++;
          if (attempts == 1) {
            return Stream<Map<String, dynamic>?>.error(
              StateError('private-token'),
            );
          }
          return Stream.value(profileData);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar seu perfil'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Pessoa Sintética'), findsOneWidget);
  });

  testWidgets('does not expose technical details when photo upload fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        profileDataStream: (_) => Stream.value(profileData),
        imagePicker: (_) async => File('synthetic-photo.jpg'),
        photoUploader: (_) async => throw StateError('private-token'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Alterar foto do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da Galeria'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível atualizar a foto. Tente novamente.'),
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
        profileDataStream: (_) => Stream.value(profileData),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pessoa Sintética'), findsOneWidget);
    expect(find.text('Informações Pessoais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

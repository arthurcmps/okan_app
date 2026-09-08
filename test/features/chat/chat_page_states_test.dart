import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/chat/domain/entities/chat_message.dart';
import 'package:okan_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:okan_app/features/chat/presentation/pages/chat_page.dart';

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({required this.messagesStreamFactory});

  final Stream<List<ChatMessage>> Function() messagesStreamFactory;
  Completer<void>? sendCompleter;
  Object? sendError;
  int watchCount = 0;
  int sendCount = 0;

  @override
  String? get currentUserId => 'current-user';

  @override
  Future<String> loadUserDisplayName(String userId) async => 'Usuário Atual';

  @override
  Stream<String?> watchUserPhotoUrl(String userId) => Stream.value(null);

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    watchCount++;
    return messagesStreamFactory();
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String text,
  }) async {
    sendCount++;
    final error = sendError;
    if (error != null) throw error;
    await sendCompleter?.future;
  }
}

void main() {
  Widget testApp(_FakeChatRepository repository) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ChatPage(
        otherUserId: 'other-user',
        otherUserName: 'Aluno Teste',
        repository: repository,
        currentUserId: 'current-user',
      ),
    );
  }

  testWidgets('shows an instructive empty conversation', (tester) async {
    final repository = _FakeChatRepository(
      messagesStreamFactory: () => Stream.value(const <ChatMessage>[]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chat-messages-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhuma mensagem ainda'), findsOneWidget);
    expect(
      find.text('Envie uma mensagem para iniciar esta conversa.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe stream error and retries', (tester) async {
    final repository = _FakeChatRepository(
      messagesStreamFactory: () => Stream<List<ChatMessage>>.error(
        StateError('technical firestore detail'),
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chat-messages-error')),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível carregar a conversa'),
      findsOneWidget,
    );
    expect(find.textContaining('technical firestore detail'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(repository.watchCount, 2);
  });

  testWidgets('preserves the conversation content', (tester) async {
    final repository = _FakeChatRepository(
      messagesStreamFactory: () => Stream.value(
        const [
          ChatMessage(senderId: 'other-user', text: 'Olá, professor!'),
          ChatMessage(senderId: 'current-user', text: 'Olá! Tudo bem?'),
        ],
      ),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Olá, professor!'), findsOneWidget);
    expect(find.text('Olá! Tudo bem?'), findsOneWidget);
    expect(find.text('Nenhuma mensagem ainda'), findsNothing);
  });

  testWidgets('blocks duplicate sends and clears text after success', (
    tester,
  ) async {
    final repository = _FakeChatRepository(
      messagesStreamFactory: () => Stream.value(const <ChatMessage>[]),
    )..sendCompleter = Completer<void>();

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Olá, tudo bem?');
    await tester.tap(find.byKey(const ValueKey('chat-send-message')));
    await tester.pump();

    expect(repository.sendCount, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('chat-send-message')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    repository.sendCompleter!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.sendCount, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('preserves the draft and hides technical send errors', (
    tester,
  ) async {
    final repository = _FakeChatRepository(
      messagesStreamFactory: () => Stream.value(const <ChatMessage>[]),
    )..sendError = StateError('token=secret');

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mensagem importante');
    await tester.tap(find.byKey(const ValueKey('chat-send-message')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Não foi possível enviar a mensagem. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('token=secret'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Mensagem importante',
    );
  });
}

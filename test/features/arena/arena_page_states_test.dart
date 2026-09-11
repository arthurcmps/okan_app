import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/arena/data/repositories/firebase_arena_repository.dart';
import 'package:okan_app/features/arena/domain/entities/arena_models.dart';
import 'package:okan_app/features/arena/domain/repositories/arena_repository.dart';
import 'package:okan_app/features/arena/presentation/pages/arena_page.dart';

class _FakeArenaRepository implements ArenaRepository {
  _FakeArenaRepository({
    this.userId = 'synthetic-user',
    Stream<List<ArenaChallenge>> Function()? challengesStreamFactory,
    Stream<List<ArenaFriendship>> Function()? friendsStreamFactory,
    Stream<List<ArenaFriendRequest>> Function()? requestsStreamFactory,
    this.onSearch,
  }) : challengesStreamFactory =
           challengesStreamFactory ??
           (() => Stream.value(const <ArenaChallenge>[])),
       friendsStreamFactory =
           friendsStreamFactory ??
           (() => Stream.value(const <ArenaFriendship>[])),
       requestsStreamFactory =
           requestsStreamFactory ??
           (() => Stream.value(const <ArenaFriendRequest>[]));

  final String? userId;
  final Stream<List<ArenaChallenge>> Function() challengesStreamFactory;
  final Stream<List<ArenaFriendship>> Function() friendsStreamFactory;
  final Stream<List<ArenaFriendRequest>> Function() requestsStreamFactory;
  final Future<ArenaFriendCandidate?> Function(String email)? onSearch;
  int challengesWatchCount = 0;

  @override
  String? get currentUserId => userId;

  @override
  String? get currentUserEmail => 'current@example.com';

  @override
  Stream<List<ArenaChallenge>> watchChallenges() {
    challengesWatchCount++;
    return challengesStreamFactory();
  }

  @override
  Stream<List<ArenaFriendship>> watchFriends() => friendsStreamFactory();

  @override
  Stream<List<ArenaFriendRequest>> watchPendingFriendRequests() =>
      requestsStreamFactory();

  @override
  Future<ArenaFriendCandidate?> findFriendCandidateByEmail(String email) async {
    return onSearch?.call(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(ArenaRepository repository, {double textScale = 1}) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ArenaPage(repository: repository),
        ),
      ),
    );
  }

  testWidgets(
    'announces challenge loading and renders an instructive empty state',
    (tester) async {
      final controller = StreamController<List<ArenaChallenge>>();
      final semantics = tester.ensureSemantics();
      addTearDown(controller.close);
      var streamCount = 0;
      final repository = _FakeArenaRepository(
        challengesStreamFactory: () {
          streamCount++;
          if (streamCount == 1) return controller.stream;
          return Stream.value(const <ArenaChallenge>[]);
        },
      );

      await tester.pumpWidget(testApp(repository));

      expect(find.bySemanticsLabel('Carregando duelos'), findsOneWidget);

      controller.add(const <ArenaChallenge>[]);
      await tester.pumpAndSettle();

      expect(find.text('Nenhum duelo ativo'), findsOneWidget);
      expect(
        find.text('Crie um duelo e convide seus amigos para começar.'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets('shows a safe challenge error and retries the stream', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _FakeArenaRepository(
      challengesStreamFactory: () {
        attempts++;
        if (attempts == 1) {
          return Stream<List<ArenaChallenge>>.error(
            StateError('private-firestore-token'),
          );
        }
        return Stream.value(const <ArenaChallenge>[]);
      },
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar seus duelos'), findsOneWidget);
    expect(find.textContaining('private-firestore-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente').first);
    await tester.pumpAndSettle();

    expect(attempts, 3);
    expect(find.text('Nenhum duelo ativo'), findsOneWidget);
  });

  testWidgets('moves from an empty friends state to athlete search', (
    tester,
  ) async {
    final repository = _FakeArenaRepository();

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meus Amigos'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum amigo na Arena'), findsOneWidget);

    await tester.tap(find.text('Buscar atleta'));
    await tester.pumpAndSettle();

    expect(find.text('Encontre um Atleta'), findsOneWidget);
    expect(find.byTooltip('Buscar atleta'), findsOneWidget);
  });

  testWidgets('does not expose technical details when athlete search fails', (
    tester,
  ) async {
    final repository = _FakeArenaRepository(
      onSearch: (_) async => throw StateError('private-search-token'),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'athlete.synthetic@example.com',
    );
    await tester.ensureVisible(find.byTooltip('Buscar atleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Buscar atleta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível buscar o atleta. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-search-token'), findsNothing);
  });

  testWidgets('supports a small screen and 200 percent text in the lobby', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeArenaRepository(
      onSearch: (email) async => ArenaFriendCandidate(
        id: 'synthetic-friend',
        name: 'Atleta Sintética',
        email: email,
      ),
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum duelo ativo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(2);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'athlete.synthetic@example.com',
    );
    await tester.ensureVisible(find.byTooltip('Buscar atleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Buscar atleta'));
    await tester.pumpAndSettle();

    expect(find.text('Encontre um Atleta'), findsOneWidget);
    expect(find.text('Atleta Sintética'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an explicit state when the session is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(_FakeArenaRepository(userId: null)));
    await tester.pumpAndSettle();

    expect(find.text('Sessão encerrada'), findsOneWidget);
    expect(find.text('Entre novamente para acessar a Arena.'), findsOneWidget);
  });

  testWidgets('opens the requested Arena tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ArenaPage(
          repository: _FakeArenaRepository(),
          initialTab: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Convites de Duelo ⚔️'), findsOneWidget);
    expect(find.text('Pedidos de Amizade 🤝'), findsOneWidget);
  });

  testWidgets('re-enters the friends tab without re-listening failure', (
    tester,
  ) async {
    final requested = StreamController<List<ArenaFriendship>>.broadcast();
    final received = StreamController<List<ArenaFriendship>>.broadcast();
    addTearDown(requested.close);
    addTearDown(received.close);
    final friends = combineArenaFriendshipStreams(
      requested: requested.stream,
      received: received.stream,
    );
    final repository = _FakeArenaRepository(
      friendsStreamFactory: () => friends,
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;

    tabs.animateTo(1);
    await tester.pumpAndSettle();
    requested.add(const <ArenaFriendship>[]);
    received.add(const <ArenaFriendship>[]);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum amigo na Arena'), findsOneWidget);

    tabs.animateTo(3);
    await tester.pumpAndSettle();
    tabs.animateTo(1);
    await tester.pumpAndSettle();
    requested.add(const <ArenaFriendship>[]);
    received.add(const <ArenaFriendship>[]);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum amigo na Arena'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

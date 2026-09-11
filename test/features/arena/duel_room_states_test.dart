import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/arena/domain/entities/arena_models.dart';
import 'package:okan_app/features/arena/domain/repositories/arena_repository.dart';
import 'package:okan_app/features/arena/presentation/pages/duel_room_page.dart';

class _FakeArenaRepository implements ArenaRepository {
  _FakeArenaRepository({
    this.userId = 'synthetic-user',
    Future<List<ArenaRankingEntry>> Function()? rankingFactory,
    Stream<List<ArenaPost>> Function()? postsFactory,
    Stream<List<ArenaComment>> Function()? commentsFactory,
    this.onCreateTextPost,
    this.onToggleReaction,
  }) : rankingFactory =
           rankingFactory ??
           (() async => const <ArenaRankingEntry>[]),
       postsFactory =
           postsFactory ??
           (() => Stream.value(const <ArenaPost>[])),
       commentsFactory =
           commentsFactory ??
           (() => Stream.value(const <ArenaComment>[]));

  final String? userId;
  final Future<List<ArenaRankingEntry>> Function() rankingFactory;
  final Stream<List<ArenaPost>> Function() postsFactory;
  final Stream<List<ArenaComment>> Function() commentsFactory;
  final Future<void> Function(String text)? onCreateTextPost;
  final Future<void> Function(String emoji)? onToggleReaction;
  int rankingAttempts = 0;
  int postWatchAttempts = 0;
  int commentWatchAttempts = 0;
  int textPostAttempts = 0;
  int reactionAttempts = 0;

  @override
  String? get currentUserId => userId;

  @override
  String? get currentUserEmail => 'athlete.synthetic@example.com';

  @override
  Future<List<ArenaRankingEntry>> calculateRanking(
    ArenaChallenge challenge,
  ) {
    rankingAttempts++;
    return rankingFactory();
  }

  @override
  Stream<List<ArenaPost>> watchPosts(String challengeId) {
    postWatchAttempts++;
    return postsFactory();
  }

  @override
  Stream<List<ArenaComment>> watchComments({
    required String challengeId,
    required String postId,
  }) {
    commentWatchAttempts++;
    return commentsFactory();
  }

  @override
  Future<void> createTextPost({
    required String challengeId,
    required String text,
  }) async {
    textPostAttempts++;
    await onCreateTextPost?.call(text);
  }

  @override
  Future<void> toggleReaction({
    required String challengeId,
    required String postId,
    required String emoji,
  }) async {
    reactionAttempts++;
    await onToggleReaction?.call(emoji);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ArenaChallenge activeChallenge() {
    return ArenaChallenge(
      id: 'synthetic-challenge',
      creatorId: 'synthetic-user',
      metric: 'constancy',
      durationDays: 30,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      participants: const <String, ArenaParticipant>{
        'synthetic-user': ArenaParticipant(
          userId: 'synthetic-user',
          name: 'Atleta Sintético',
          status: 'accepted',
        ),
        'synthetic-friend': ArenaParticipant(
          userId: 'synthetic-friend',
          name: 'Amiga Sintética',
          status: 'accepted',
        ),
      },
      imagesDeleted: false,
    );
  }

  ArenaPost wallPost() {
    return ArenaPost(
      id: 'synthetic-post',
      authorId: 'synthetic-friend',
      authorName: 'Amiga Sintética',
      text: 'Treino concluído',
      createdAt: DateTime(2026, 9, 11, 10),
      reactions: const <String, List<String>>{
        '🔥': <String>['synthetic-user'],
      },
      commentsCount: 0,
    );
  }

  Widget testApp(_FakeArenaRepository repository, {double textScale = 1}) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DuelRoomPage(
            challenge: activeChallenge(),
            repository: repository,
          ),
        ),
      ),
    );
  }

  Future<void> openWall(WidgetTester tester) async {
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    tabs.animateTo(1);
    await tester.pumpAndSettle();
  }

  testWidgets('shows loading and an instructive empty ranking state', (
    tester,
  ) async {
    final completer = Completer<List<ArenaRankingEntry>>();
    final repository = _FakeArenaRepository(
      rankingFactory: () => completer.future,
    );

    await tester.pumpWidget(testApp(repository));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Carregando placar do duelo',
      ),
      findsOneWidget,
    );

    completer.complete(const <ArenaRankingEntry>[]);
    await tester.pumpAndSettle();

    expect(find.text('Placar ainda sem resultados'), findsOneWidget);
    expect(repository.rankingAttempts, 1);
  });

  testWidgets('shows a safe ranking error and retries without rebuilding it', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _FakeArenaRepository(
      rankingFactory: () {
        attempts++;
        if (attempts == 1) {
          return Future<List<ArenaRankingEntry>>.error(
            StateError('private-ranking-token'),
          );
        }
        return Future.value(const <ArenaRankingEntry>[]);
      },
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o placar'), findsOneWidget);
    expect(find.textContaining('private-ranking-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.rankingAttempts, 2);
    expect(find.text('Placar ainda sem resultados'), findsOneWidget);
  });

  testWidgets('shows a safe wall error and retries its cached stream', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _FakeArenaRepository(
      postsFactory: () {
        attempts++;
        if (attempts == 1) {
          return Stream<List<ArenaPost>>.error(
            StateError('private-wall-token'),
          );
        }
        return Stream.value(const <ArenaPost>[]);
      },
    );

    await tester.pumpWidget(testApp(repository));
    await openWall(tester);

    expect(find.text('Não foi possível carregar o mural'), findsOneWidget);
    expect(find.textContaining('private-wall-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.postWatchAttempts, 2);
    expect(find.text('Nenhuma publicação ainda'), findsOneWidget);
  });

  testWidgets('blocks a duplicated text post while the first one is pending', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _FakeArenaRepository(
      onCreateTextPost: (_) => completer.future,
    );

    await tester.pumpWidget(testApp(repository));
    await openWall(tester);
    await tester.enterText(find.byType(TextField), 'Mensagem sintética');
    await tester.tap(find.byTooltip('Publicar mensagem no mural'));
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Publicar mensagem no mural'),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendButton.onPressed, isNull);
    expect(repository.textPostAttempts, 1);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Publicação enviada.'), findsOneWidget);
  });

  testWidgets('labels reactions and prevents a repeated reaction request', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _FakeArenaRepository(
      postsFactory: () => Stream.value(<ArenaPost>[wallPost()]),
      onToggleReaction: (_) => completer.future,
    );

    await tester.pumpWidget(testApp(repository));
    await openWall(tester);

    final fireReaction = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Remover reação fogo. 1 reações.',
    );
    expect(fireReaction, findsOneWidget);
    expect(tester.getSize(fireReaction).height, greaterThanOrEqualTo(48));

    await tester.tap(fireReaction);
    await tester.pump();
    await tester.tap(fireReaction);
    await tester.pump();

    expect(repository.reactionAttempts, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows a safe comments error and retries inside the sheet', (
    tester,
  ) async {
    var attempts = 0;
    final repository = _FakeArenaRepository(
      postsFactory: () => Stream.value(<ArenaPost>[wallPost()]),
      commentsFactory: () {
        attempts++;
        if (attempts == 1) {
          return Stream<List<ArenaComment>>.error(
            StateError('private-comments-token'),
          );
        }
        return Stream.value(const <ArenaComment>[]);
      },
    );

    await tester.pumpWidget(testApp(repository));
    await openWall(tester);
    await tester.tap(find.text('0 Comentários'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar os comentários'),
      findsOneWidget,
    );
    expect(find.textContaining('private-comments-token'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.commentWatchAttempts, 2);
    expect(find.text('Nenhum comentário ainda'), findsOneWidget);
  });

  testWidgets('supports the header on a small screen and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(_FakeArenaRepository(), textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('Placar ainda sem resultados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports ranking on a small screen and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeArenaRepository(
      rankingFactory: () async => const <ArenaRankingEntry>[
        ArenaRankingEntry(
          userId: 'synthetic-friend',
          name: 'Amiga Sintética com Nome Extenso',
          delta: 12,
        ),
      ],
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('Amiga Sintética com Nome Extenso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports the wall on a small screen and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeArenaRepository(
      postsFactory: () => Stream.value(<ArenaPost>[wallPost()]),
    );

    await tester.pumpWidget(testApp(repository, textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await openWall(tester);

    expect(find.text('Treino concluído'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an explicit state when the session is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(_FakeArenaRepository(userId: null)));
    await tester.pumpAndSettle();

    expect(find.text('Sessão encerrada'), findsOneWidget);
    expect(
      find.text('Entre novamente para acessar este duelo.'),
      findsOneWidget,
    );
  });
}

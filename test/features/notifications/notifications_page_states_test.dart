import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/presentation/pages/notifications_page.dart';
import 'package:okan_app/features/notifications/domain/entities/notification_models.dart';
import 'package:okan_app/features/notifications/domain/repositories/notifications_repository.dart';

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({
    required this.invitesStreamFactory,
    required this.notificationsStreamFactory,
  });

  final Stream<List<PendingTrainerInvite>> Function() invitesStreamFactory;
  final Stream<List<OkanNotification>> Function() notificationsStreamFactory;
  Completer<void>? respondCompleter;
  Object? markAllError;
  int inviteWatchCount = 0;
  int notificationWatchCount = 0;
  int respondCount = 0;
  int markAllCount = 0;

  @override
  Stream<List<PendingTrainerInvite>> watchPendingInvites(String studentId) {
    inviteWatchCount++;
    return invitesStreamFactory();
  }

  @override
  Stream<List<OkanNotification>> watchRecentNotifications(String userId) {
    notificationWatchCount++;
    return notificationsStreamFactory();
  }

  @override
  Future<void> respondStudentInvite({
    required String inviteId,
    required bool accept,
  }) async {
    respondCount++;
    await respondCompleter?.future;
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    markAllCount++;
    final error = markAllError;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget testApp(_FakeNotificationsRepository repository) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: NotificationsPage(
        repository: repository,
        userId: 'student-1',
      ),
    );
  }

  testWidgets('distinguishes pending invite loading from an empty state', (
    tester,
  ) async {
    final pendingInvites = StreamController<List<PendingTrainerInvite>>();
    addTearDown(pendingInvites.close);
    final repository = _FakeNotificationsRepository(
      invitesStreamFactory: () => pendingInvites.stream,
      notificationsStreamFactory: () =>
          Stream.value(const <OkanNotification>[]),
    );
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Carregando convites pendentes'),
      findsOneWidget,
    );
    expect(find.text('Nenhum convite pendente.'), findsNothing);

    semantics.dispose();
  });

  testWidgets('shows safe stream errors and retries independently', (
    tester,
  ) async {
    final repository = _FakeNotificationsRepository(
      invitesStreamFactory: () => Stream<List<PendingTrainerInvite>>.error(
        StateError('invite technical detail'),
      ),
      notificationsStreamFactory: () =>
          Stream.value(const <OkanNotification>[]),
    );

    await tester.pumpWidget(testApp(repository));
    await tester.pump();

    const errorKey = ValueKey('pending-invites-error');
    expect(find.byKey(errorKey), findsOneWidget);
    expect(find.text('Não foi possível carregar os convites.'), findsOneWidget);
    expect(find.textContaining('invite technical detail'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(errorKey),
        matching: find.text('Tentar novamente'),
      ),
    );
    await tester.pump();

    expect(repository.inviteWatchCount, 2);
    expect(repository.notificationWatchCount, 1);
  });

  testWidgets('blocks both invite actions while responding', (tester) async {
    const invite = PendingTrainerInvite(
      id: 'invite-1',
      personalName: 'Professor Teste',
    );
    final repository = _FakeNotificationsRepository(
      invitesStreamFactory: () => Stream.value(const [invite]),
      notificationsStreamFactory: () =>
          Stream.value(const <OkanNotification>[]),
    )..respondCompleter = Completer<void>();

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    const acceptKey = ValueKey('accept-invite-invite-1');
    const declineKey = ValueKey('decline-invite-invite-1');
    await tester.tap(find.byKey(acceptKey));
    await tester.pump();

    expect(repository.respondCount, 1);
    expect(tester.widget<ElevatedButton>(find.byKey(acceptKey)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(declineKey)).onPressed, isNull);

    repository.respondCompleter!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.respondCount, 1);
    expect(
      find.text('Convite aceito! Agora vocês estão conectados.'),
      findsOneWidget,
    );
  });

  testWidgets('handles mark-all failure without exposing details', (
    tester,
  ) async {
    final repository = _FakeNotificationsRepository(
      invitesStreamFactory: () =>
          Stream.value(const <PendingTrainerInvite>[]),
      notificationsStreamFactory: () =>
          Stream.value(const <OkanNotification>[]),
    )..markAllError = StateError('token=secret');

    await tester.pumpWidget(testApp(repository));
    await tester.pumpAndSettle();

    const actionKey = ValueKey('notifications-mark-all-read');
    await tester.tap(find.byKey(actionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.markAllCount, 1);
    expect(
      find.text(
        'Não foi possível marcar as notificações. Tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('token=secret'), findsNothing);
    expect(tester.widget<IconButton>(find.byKey(actionKey)).onPressed, isNotNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/students/domain/entities/pending_student_invite.dart';
import 'package:okan_app/features/students/domain/entities/student_summary.dart';
import 'package:okan_app/features/students/presentation/widgets/students_lists.dart';

void main() {
  const colors = ColorScheme.dark(
    primary: Color(0xFFCCFF00),
    onPrimary: Color(0xFF120E16),
    secondary: Color(0xFFE07A5F),
    onSecondary: Colors.white,
    surface: Color(0xFF1E1826),
    error: Color(0xFFFF453A),
  );

  ThemeData testTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      cardTheme: const CardThemeData(color: Color(0xFF1E1826)),
    );
  }

  Widget testApp(Widget child) {
    return MaterialApp(
      theme: testTheme(),
      home: Scaffold(body: child),
    );
  }

  StudentSummary student(int index) {
    return StudentSummary(
      id: 'student-$index',
      name: 'Aluno $index',
      email: 'aluno$index@example.com',
      photoUrl: null,
      professorId: 'professional-1',
    );
  }

  testWidgets('shows an instructive active-students empty state', (
    tester,
  ) async {
    var inviteCalls = 0;

    await tester.pumpWidget(
      testApp(
        ActiveStudentsList(
          isLoading: false,
          hasError: false,
          isPremium: false,
          students: const [],
          onInvite: () => inviteCalls++,
          onOpenStudent: (_) {},
          onOpenBlockedStudent: (_) {},
          onChat: (_) {},
          onUnlink: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('active-students-empty')),
      findsOneWidget,
    );
    expect(find.text('Nenhum aluno ativo'), findsOneWidget);
    expect(
      find.text(
        'Convide seu primeiro aluno para acompanhar treinos e evolução.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Convidar aluno'));
    expect(inviteCalls, 1);
  });

  testWidgets('preserves active student actions and base-plan blocking', (
    tester,
  ) async {
    final opened = <String>[];
    final blocked = <String>[];
    final chats = <String>[];
    final unlinked = <String>[];
    final students = [student(1), student(2), student(3), student(4)];

    await tester.pumpWidget(
      testApp(
        ActiveStudentsList(
          isLoading: false,
          hasError: false,
          isPremium: false,
          students: students,
          onInvite: () {},
          onOpenStudent: (item) => opened.add(item.id),
          onOpenBlockedStudent: (item) => blocked.add(item.id),
          onChat: (item) => chats.add(item.id),
          onUnlink: (item) => unlinked.add(item.id),
        ),
      ),
    );

    expect(find.text('4 alunos ativos'), findsOneWidget);
    expect(find.byTooltip('Conversar com Aluno 1'), findsOneWidget);
    expect(find.byTooltip('Desvincular Aluno 1'), findsOneWidget);

    await tester.tap(find.text('Aluno 1'));
    expect(opened, ['student-1']);

    await tester.tap(
      find.byKey(const ValueKey('chat-student-student-1')),
    );
    expect(chats, ['student-1']);

    await tester.tap(
      find.byKey(const ValueKey('unlink-student-student-1')),
    );
    expect(unlinked, ['student-1']);

    final blockedCard = find.byKey(
      const ValueKey('active-student-student-4'),
    );
    await tester.scrollUntilVisible(blockedCard, 240);
    await tester.tap(find.text('Aluno 4'));

    expect(blocked, ['student-4']);
    expect(
      find.byKey(const ValueKey('chat-student-student-4')),
      findsNothing,
    );
    expect(find.textContaining('Acesso limitado'), findsOneWidget);
  });

  testWidgets('distinguishes pending loading, empty and populated states', (
    tester,
  ) async {
    var inviteCalls = 0;
    final cancelled = <String>[];

    await tester.pumpWidget(
      testApp(
        PendingStudentInvitesList(
          isLoading: true,
          hasError: false,
          invites: const [],
          onInvite: () => inviteCalls++,
          onCancel: (invite) => cancelled.add(invite.id),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('pending-invites-loading')),
      findsOneWidget,
    );
    expect(find.text('Nenhum convite pendente'), findsNothing);

    await tester.pumpWidget(
      testApp(
        PendingStudentInvitesList(
          isLoading: false,
          hasError: false,
          invites: const [],
          onInvite: () => inviteCalls++,
          onCancel: (invite) => cancelled.add(invite.id),
        ),
      ),
    );

    expect(find.text('Nenhum convite pendente'), findsOneWidget);
    await tester.tap(find.text('Convidar aluno'));
    expect(inviteCalls, 1);

    const invite = PendingStudentInvite(
      id: 'invite-1',
      studentEmail: 'aluno@example.com',
    );
    await tester.pumpWidget(
      testApp(
        PendingStudentInvitesList(
          isLoading: false,
          hasError: false,
          invites: const [invite],
          onInvite: () => inviteCalls++,
          onCancel: (item) => cancelled.add(item.id),
        ),
      ),
    );

    expect(find.text('1 convite pendente'), findsOneWidget);
    expect(find.text('aluno@example.com'), findsOneWidget);
    expect(
      find.byTooltip('Cancelar convite para aluno@example.com'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('cancel-invite-invite-1')),
    );
    expect(cancelled, ['invite-1']);
  });
}

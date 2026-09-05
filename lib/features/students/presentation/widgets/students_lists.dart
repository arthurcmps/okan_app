import 'package:flutter/material.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/pending_student_invite.dart';
import '../../domain/entities/student_summary.dart';

class ActiveStudentsList extends StatelessWidget {
  const ActiveStudentsList({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.isPremium,
    required this.students,
    required this.onOpenStudent,
    required this.onOpenBlockedStudent,
    required this.onChat,
    required this.onUnlink,
  });

  final bool isLoading;
  final bool hasError;
  final bool isPremium;
  final List<StudentSummary> students;
  final ValueChanged<StudentSummary> onOpenStudent;
  final ValueChanged<StudentSummary> onOpenBlockedStudent;
  final ValueChanged<StudentSummary> onChat;
  final ValueChanged<StudentSummary> onUnlink;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _StudentsLoadingState(
        key: ValueKey('active-students-loading'),
        label: 'Carregando alunos...',
      );
    }

    if (hasError) {
      return const _StudentsMessageState(
        key: ValueKey('active-students-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar seus alunos',
        description: 'Confira sua conexão e tente novamente em instantes.',
      );
    }

    if (students.isEmpty) {
      return _StudentsMessageState(
        key: const ValueKey('active-students-empty'),
        icon: Icons.people_outline,
        title: 'Nenhum aluno ativo',
        description:
            'Convide seu primeiro aluno para acompanhar treinos e evolução.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: students.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _StudentsSummaryCard(
            icon: Icons.groups_2_outlined,
            title: _activeStudentsLabel(students.length),
            description: isPremium
                ? 'Seu plano permite gerenciar todos os vínculos.'
                : 'No Plano Base, os 3 primeiros vínculos ficam disponíveis.',
          );
        }

        final studentIndex = index - 1;
        final student = students[studentIndex];
        final isBlocked = !isPremium && studentIndex > 2;

        return _ActiveStudentCard(
          student: student,
          isBlocked: isBlocked,
          onTap: () => isBlocked
              ? onOpenBlockedStudent(student)
              : onOpenStudent(student),
          onChat: isBlocked ? null : () => onChat(student),
          onUnlink: () => onUnlink(student),
        );
      },
    );
  }

  String _activeStudentsLabel(int count) {
    return count == 1 ? '1 aluno ativo' : '$count alunos ativos';
  }
}

class PendingStudentInvitesList extends StatelessWidget {
  const PendingStudentInvitesList({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.invites,
    required this.onCancel,
  });

  final bool isLoading;
  final bool hasError;
  final List<PendingStudentInvite> invites;
  final ValueChanged<PendingStudentInvite> onCancel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _StudentsLoadingState(
        key: ValueKey('pending-invites-loading'),
        label: 'Carregando convites...',
      );
    }

    if (hasError) {
      return const _StudentsMessageState(
        key: ValueKey('pending-invites-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar os convites',
        description: 'Confira sua conexão e tente novamente em instantes.',
      );
    }

    if (invites.isEmpty) {
      return _StudentsMessageState(
        key: const ValueKey('pending-invites-empty'),
        icon: Icons.mark_email_read_outlined,
        title: 'Nenhum convite pendente',
        description:
            'Os convites enviados e ainda não aceitos aparecerão aqui.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: invites.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = invites.length;
          return _StudentsSummaryCard(
            icon: Icons.outgoing_mail,
            title:
                count == 1 ? '1 convite pendente' : '$count convites pendentes',
            description:
                'Você pode cancelar um convite enquanto ele aguarda aceite.',
          );
        }

        final invite = invites[index - 1];
        return _PendingInviteCard(
          invite: invite,
          onCancel: () => onCancel(invite),
        );
      },
    );
  }
}

class _StudentsSummaryCard extends StatelessWidget {
  const _StudentsSummaryCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.secondary.withOpacity(0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.secondary.withOpacity(0.16),
              foregroundColor: colors.secondary,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveStudentCard extends StatelessWidget {
  const _ActiveStudentCard({
    required this.student,
    required this.isBlocked,
    required this.onTap,
    required this.onChat,
    required this.onUnlink,
  });

  final StudentSummary student;
  final bool isBlocked;
  final VoidCallback onTap;
  final VoidCallback? onChat;
  final VoidCallback onUnlink;

  String get _name => student.name.isEmpty ? 'Aluno' : student.name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disabledColor = colors.onSurface.withOpacity(0.48);

    return Card(
      key: ValueKey('active-student-${student.id}'),
      color: isBlocked ? colors.surface.withOpacity(0.55) : colors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBlocked
              ? colors.tertiary.withOpacity(0.38)
              : colors.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: isBlocked
            ? CircleAvatar(
                backgroundColor: colors.tertiaryContainer,
                foregroundColor: colors.onTertiaryContainer,
                child: const Icon(Icons.lock_outline),
              )
            : UserAvatar(
                photoUrl: student.photoUrl,
                name: _name,
                radius: 24,
              ),
        title: Text(
          _name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: isBlocked ? disabledColor : colors.onSurface,
          ),
        ),
        subtitle: Text(
          isBlocked ? 'Acesso limitado • ${student.email}' : student.email,
          maxLines: isBlocked ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: isBlocked
                ? disabledColor
                : colors.onSurfaceVariant,
          ),
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onChat != null)
              IconButton(
                key: ValueKey('chat-student-${student.id}'),
                tooltip: 'Conversar com $_name',
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: colors.primary,
                ),
                onPressed: onChat,
              ),
            IconButton(
              key: ValueKey('unlink-student-${student.id}'),
              tooltip: 'Desvincular $_name',
              icon: Icon(Icons.person_remove_outlined, color: colors.error),
              onPressed: onUnlink,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({
    required this.invite,
    required this.onCancel,
  });

  final PendingStudentInvite invite;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: ValueKey('pending-invite-${invite.id}'),
      color: colors.surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: colors.secondary.withOpacity(0.14),
          foregroundColor: colors.secondary,
          child: const Icon(Icons.mark_email_unread_outlined),
        ),
        title: Text(
          invite.studentEmail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(color: colors.onSurface),
        ),
        subtitle: Text(
          'Aguardando aceite',
          style: textTheme.bodySmall?.copyWith(color: colors.secondary),
        ),
        trailing: IconButton(
          key: ValueKey('cancel-invite-${invite.id}'),
          tooltip: 'Cancelar convite para ${invite.studentEmail}',
          icon: Icon(Icons.close, color: colors.error),
          onPressed: onCancel,
        ),
      ),
    );
  }
}

class _StudentsLoadingState extends StatelessWidget {
  const _StudentsLoadingState({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: CircularProgressIndicator(color: colors.secondary),
      ),
    );
  }
}

class _StudentsMessageState extends StatelessWidget {
  const _StudentsMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.secondary.withOpacity(0.12),
              foregroundColor: colors.secondary,
              child: Icon(icon, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../notifications/data/repositories/firebase_notifications_repository.dart';
import '../../../notifications/domain/entities/notification_models.dart';
import '../../../notifications/domain/repositories/notifications_repository.dart';
import '../../data/services/professional_relationships_service.dart';
import 'chat_page.dart';
import 'student_detail_page.dart';
import 'weekly_plan_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    this.repository,
    this.userId,
  });

  final NotificationsRepository? repository;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Não logado')),
      );
    }

    final notificationsRepository =
        repository ?? FirebaseNotificationsRepository();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notificações',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.textSub),
            onPressed: () => notificationsRepository
                .markAllNotificationsRead(currentUserId),
            tooltip: 'Marcar todas como lidas',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'CONVITES PENDENTES',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            _buildInvitesStream(
              notificationsRepository,
              currentUserId,
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'RECENTES',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            _buildGeneralNotificationsStream(
              context,
              notificationsRepository,
              currentUserId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitesStream(
    NotificationsRepository repository,
    String userId,
  ) {
    return StreamBuilder<List<PendingTrainerInvite>>(
      stream: repository.watchPendingInvites(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('Nenhum convite pendente.');
        }

        return Column(
          children: snapshot.data!.map((invite) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person_add, color: Colors.black),
                    ),
                    title: Text(
                      invite.personalName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Quer ser seu treinador no Okan',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _responderConvite(
                              context,
                              repository,
                              invite.id,
                              false,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.error,
                              ),
                            ),
                            child: const Text(
                              'Recusar',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _responderConvite(
                              context,
                              repository,
                              invite.id,
                              true,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text(
                              'Aceitar',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGeneralNotificationsStream(
    BuildContext context,
    NotificationsRepository repository,
    String userId,
  ) {
    return StreamBuilder<List<OkanNotification>>(
      stream: repository.watchRecentNotifications(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('Nenhuma notificação recente.');
        }

        final notifications = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];

            return Dismissible(
              key: Key(notification.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) {
                repository.deleteNotification(
                  userId: userId,
                  notificationId: notification.id,
                );
              },
              child: GestureDetector(
                onTap: () => _handleNotificationTap(
                  context,
                  repository,
                  userId,
                  notification,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? AppColors.surface.withOpacity(0.5)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: notification.isRead
                        ? null
                        : Border(
                            left: BorderSide(
                              color: _getColorByNotification(notification),
                              width: 4,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      _getIconByNotification(notification),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: TextStyle(
                                color: notification.isRead
                                    ? Colors.white54
                                    : Colors.white,
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              style: const TextStyle(
                                color: AppColors.textSub,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(notification.occurredAt),
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getColorByNotification(notification),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationsRepository repository,
    String currentUserId,
    OkanNotification notification,
  ) async {
    if (!notification.isRead) {
      await repository.markNotificationRead(
        userId: currentUserId,
        notificationId: notification.id,
      );
    }

    if (!context.mounted) return;

    switch (notification.type) {
      case 'invite':
        final inviteId = notification.actionId;
        if (inviteId != null && inviteId.isNotEmpty) {
          await _mostrarDialogoConvite(
            context,
            repository,
            inviteId,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Olhe no topo da tela, nos seus convites pendentes!',
              ),
            ),
          );
        }
        break;

      case 'message':
        final senderId = notification.actionId;
        if (senderId == null || senderId.isEmpty) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              otherUserId: senderId,
              otherUserName: notification.senderName,
            ),
          ),
        );
        break;

      case 'workout':
      case 'workout_update':
        final currentProfile =
            await repository.loadUserProfile(currentUserId);
        final isProfessor =
            currentProfile?.isTrainingProfessional == true;

        if (!isProfessor) {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeeklyPlanPage(
                  studentId: currentUserId,
                  studentName: 'Meus Treinos',
                ),
              ),
            );
          }
          break;
        }

        final studentId =
            notification.actionId ?? notification.studentId;

        if (studentId != null &&
            studentId.isNotEmpty &&
            studentId != currentUserId) {
          final studentProfile =
              await repository.loadUserProfile(studentId);

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailPage(
                  studentId: studentId,
                  studentName: studentProfile?.name ?? 'Aluno',
                  studentEmail: studentProfile?.email ?? '',
                ),
              ),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Abra a aba 'Meus Alunos' para conferir o treino.",
              ),
            ),
          );
        }
        break;
    }
  }

  Future<void> _mostrarDialogoConvite(
    BuildContext context,
    NotificationsRepository repository,
    String inviteId,
  ) async {
    try {
      final invite = await repository.loadPendingInvite(inviteId);
      if (!context.mounted) return;

      if (invite == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este convite já foi respondido ou não está mais disponível.',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.white,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Convite Pendente',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '${invite.personalName} quer ser o seu treinador no Okan.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _responderConvite(
                  context,
                  repository,
                  inviteId,
                  false,
                );
              },
              child: const Text(
                'Recusar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _responderConvite(
                  context,
                  repository,
                  inviteId,
                  true,
                );
              },
              child: const Text(
                'Aceitar',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $error')),
        );
      }
    }
  }

  Color _getColorByNotification(OkanNotification notification) {
    final title = notification.title.toLowerCase();

    if (title.contains('vencido')) return Colors.redAccent;
    if (title.contains('vencendo') || title.contains('alteração')) {
      return Colors.amber;
    }
    if (title.contains('feedback')) return Colors.blueAccent;

    switch (notification.type) {
      case 'message':
        return Colors.blueAccent;
      case 'workout':
      case 'workout_update':
        return AppColors.primary;
      case 'assessment':
        return AppColors.secondary;
      case 'invite':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _getIconByNotification(OkanNotification notification) {
    final title = notification.title.toLowerCase();
    final color = _getColorByNotification(notification);
    late final IconData icon;

    if (title.contains('vencido')) {
      icon = Icons.warning_amber_rounded;
    } else if (title.contains('vencendo')) {
      icon = Icons.timer_outlined;
    } else if (title.contains('alteração')) {
      icon = Icons.change_circle_outlined;
    } else if (title.contains('feedback')) {
      icon = Icons.feedback_outlined;
    } else {
      switch (notification.type) {
        case 'message':
          icon = Icons.chat_bubble;
          break;
        case 'workout':
        case 'workout_update':
          icon = Icons.fitness_center;
          break;
        case 'assessment':
          icon = Icons.monitor_weight;
          break;
        case 'invite':
          icon = Icons.person_add;
          break;
        default:
          icon = Icons.notifications;
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return DateFormat('dd/MM').format(timestamp);
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white30),
      ),
    );
  }

  Future<void> _responderConvite(
    BuildContext context,
    NotificationsRepository repository,
    String inviteId,
    bool aceitar,
  ) async {
    try {
      await repository.respondStudentInvite(
        inviteId: inviteId,
        accept: aceitar,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aceitar
                  ? 'Convite aceito! Agora vocês estão conectados.'
                  : 'Convite recusado.',
            ),
            backgroundColor: aceitar
                ? AppColors.success
                : Colors.grey,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              professionalRelationshipErrorMessage(error),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

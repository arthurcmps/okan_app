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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.repository,
    this.userId,
  });

  final NotificationsRepository? repository;
  final String? userId;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsRepository _repository;
  late final String? _currentUserId;
  Stream<List<PendingTrainerInvite>>? _pendingInvitesStream;
  Stream<List<OkanNotification>>? _recentNotificationsStream;
  final Map<String, bool> _processingInvites = <String, bool>{};
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseNotificationsRepository();
    _currentUserId =
        widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    final currentUserId = _currentUserId;
    if (currentUserId != null) {
      _pendingInvitesStream = _repository.watchPendingInvites(currentUserId);
      _recentNotificationsStream =
          _repository.watchRecentNotifications(currentUserId);
    }
  }

  void _retryPendingInvites() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    setState(() {
      _pendingInvitesStream = _repository.watchPendingInvites(currentUserId);
    });
  }

  void _retryRecentNotifications() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    setState(() {
      _recentNotificationsStream =
          _repository.watchRecentNotifications(currentUserId);
    });
  }

  Future<void> _markAllRead() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || _isMarkingAllRead) return;

    setState(() => _isMarkingAllRead = true);
    try {
      await _repository.markAllNotificationsRead(currentUserId);
    } catch (error) {
      debugPrint('NotificationsPage/markAllRead: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível marcar as notificações. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Não logado')),
      );
    }

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
            key: const ValueKey('notifications-mark-all-read'),
            icon: _isMarkingAllRead
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textSub,
                    ),
                  )
                : const Icon(Icons.done_all, color: AppColors.textSub),
            onPressed: _isMarkingAllRead ? null : _markAllRead,
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
              _repository,
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
              _repository,
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
      stream: _pendingInvitesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildInlineLoading('Carregando convites pendentes');
        }

        if (snapshot.hasError) {
          return _buildInlineError(
            key: const ValueKey('pending-invites-error'),
            message: 'Não foi possível carregar os convites.',
            onRetry: _retryPendingInvites,
          );
        }

        final invites = snapshot.data ?? const <PendingTrainerInvite>[];
        if (invites.isEmpty) {
          return _buildEmptyState('Nenhum convite pendente.');
        }

        return Column(
          children: invites.map((invite) {
            final processingDecision = _processingInvites[invite.id];
            final isProcessing = processingDecision != null;
            return Container(
              key: ValueKey('pending-invite-${invite.id}'),
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
                            key: ValueKey('decline-invite-${invite.id}'),
                            onPressed: isProcessing
                                ? null
                                : () => _responderConvite(
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
                            child: processingDecision == false
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.error,
                                    ),
                                  )
                                : const Text(
                                    'Recusar',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            key: ValueKey('accept-invite-${invite.id}'),
                            onPressed: isProcessing
                                ? null
                                : () => _responderConvite(
                                    context,
                                    repository,
                                    invite.id,
                                    true,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: processingDecision == true
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
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
      stream: _recentNotificationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildInlineLoading('Carregando notificações recentes');
        }

        if (snapshot.hasError) {
          return _buildInlineError(
            key: const ValueKey('recent-notifications-error'),
            message: 'Não foi possível carregar as notificações.',
            onRetry: _retryRecentNotifications,
          );
        }

        final notifications = snapshot.data ?? const <OkanNotification>[];
        if (notifications.isEmpty) {
          return _buildEmptyState('Nenhuma notificação recente.');
        }

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
      debugPrint('NotificationsPage/loadPendingInvite: ${error.runtimeType}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o convite. Tente novamente.',
            ),
          ),
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

  Widget _buildInlineLoading(String label) {
    return SizedBox(
      height: 88,
      child: Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: label,
          child: const ExcludeSemantics(
            child: CircularProgressIndicator(
              color: AppColors.secondary,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError({
    required Key key,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Semantics(
      key: key,
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSub),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _responderConvite(
    BuildContext context,
    NotificationsRepository repository,
    String inviteId,
    bool aceitar,
  ) async {
    if (_processingInvites.containsKey(inviteId)) return;
    setState(() => _processingInvites[inviteId] = aceitar);

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
      debugPrint('NotificationsPage/respondInvite: ${error.runtimeType}');
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
    } finally {
      if (mounted) {
        setState(() => _processingInvites.remove(inviteId));
      }
    }
  }
}

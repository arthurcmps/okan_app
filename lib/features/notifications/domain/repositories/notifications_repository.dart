import '../entities/notification_models.dart';

abstract interface class NotificationsRepository {
  Stream<List<PendingTrainerInvite>> watchPendingInvites(String studentId);

  Stream<List<OkanNotification>> watchRecentNotifications(String userId);

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  });

  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  });

  Future<void> markAllNotificationsRead(String userId);

  Future<PendingTrainerInvite?> loadPendingInvite(String inviteId);

  Future<NotificationUserProfile?> loadUserProfile(String userId);

  Future<void> respondStudentInvite({
    required String inviteId,
    required bool accept,
  });
}

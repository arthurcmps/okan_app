class PendingTrainerInvite {
  const PendingTrainerInvite({
    required this.id,
    required this.personalName,
  });

  final String id;
  final String personalName;
}

class OkanNotification {
  const OkanNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.senderName,
    required this.actionId,
    required this.studentId,
    required this.isRead,
    required this.occurredAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String senderName;
  final String? actionId;
  final String? studentId;
  final bool isRead;
  final DateTime? occurredAt;
}

class NotificationUserProfile {
  const NotificationUserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.isTrainingProfessional,
  });

  final String id;
  final String name;
  final String email;
  final bool isTrainingProfessional;
}

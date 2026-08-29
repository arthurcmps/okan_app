import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/services/professional_relationships_service.dart';
import '../../domain/entities/notification_models.dart';
import '../../domain/repositories/notifications_repository.dart';

class FirebaseNotificationsRepository implements NotificationsRepository {
  FirebaseNotificationsRepository({
    FirebaseFirestore? firestore,
    ProfessionalRelationshipsService? relationships,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _relationships = relationships ?? ProfessionalRelationshipsService();

  final FirebaseFirestore _firestore;
  final ProfessionalRelationshipsService _relationships;

  @override
  Stream<List<PendingTrainerInvite>> watchPendingInvites(String studentId) {
    return _firestore
        .collection('invites')
        .where('studentUid', isEqualTo: studentId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) {
                  final data = document.data();
                  return PendingTrainerInvite(
                    id: document.id,
                    personalName: _stringOrFallback(
                      data['personalName'] ?? data['fromPersonalName'],
                      'Personal',
                    ),
                  );
                },
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<List<OkanNotification>> watchRecentNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => _notificationFrom(
                  document.id,
                  document.data(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) {
    return _notificationRef(userId, notificationId).delete();
  }

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) {
    return _notificationRef(userId, notificationId).update({
      'isRead': true,
    });
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final document in snapshot.docs) {
      batch.update(document.reference, {'isRead': true});
    }

    await batch.commit();
  }

  @override
  Future<PendingTrainerInvite?> loadPendingInvite(String inviteId) async {
    final snapshot = await _firestore.collection('invites').doc(inviteId).get();
    final data = snapshot.data();

    if (data == null || data['status'] != 'pending') {
      return null;
    }

    return PendingTrainerInvite(
      id: snapshot.id,
      personalName: _stringOrFallback(
        data['personalName'] ?? data['fromPersonalName'],
        'Personal',
      ),
    );
  }

  @override
  Future<NotificationUserProfile?> loadUserProfile(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) return null;

    final user = UserModel.fromDocument(snapshot);

    return NotificationUserProfile(
      id: user.id,
      name: user.name.isEmpty ? 'Aluno' : user.name,
      email: user.email,
      isTrainingProfessional: user.isTrainingProfessional,
    );
  }

  @override
  Future<void> respondStudentInvite({
    required String inviteId,
    required bool accept,
  }) async {
    await _relationships.respondStudentInvite(
      inviteId: inviteId,
      accept: accept,
    );
  }

  DocumentReference<Map<String, dynamic>> _notificationRef(
    String userId,
    String notificationId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);
  }

  static OkanNotification _notificationFrom(
    String id,
    Map<String, dynamic> data,
  ) {
    return OkanNotification(
      id: id,
      type: _stringOrFallback(data['type'], ''),
      title: _stringOrFallback(data['title'], 'Notificação'),
      body: _stringOrFallback(data['body'], ''),
      senderName: _stringOrFallback(data['senderName'], 'Chat'),
      actionId: _nullableString(data['actionId']),
      studentId: _nullableString(data['studentId']),
      isRead: data['isRead'] == true,
      occurredAt: _dateFrom(data['timestamp']),
    );
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static String _stringOrFallback(dynamic value, String fallback) {
    final normalized = _nullableString(value);
    return normalized ?? fallback;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

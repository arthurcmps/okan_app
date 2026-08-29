import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/services/professional_relationships_service.dart';
import '../../domain/entities/pending_student_invite.dart';
import '../../domain/entities/student_invite_creation_result.dart';
import '../../domain/entities/student_summary.dart';
import '../../domain/repositories/students_repository.dart';

bool normalizePremiumEntitlement(dynamic value) {
  if (value == true) return true;

  if (value is String) {
    return value.trim().toLowerCase() == 'true';
  }

  return false;
}

class FirebaseStudentsRepository implements StudentsRepository {
  FirebaseStudentsRepository({
    FirebaseFirestore? firestore,
    ProfessionalRelationshipsService? relationships,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _relationships = relationships ?? ProfessionalRelationshipsService();

  final FirebaseFirestore _firestore;
  final ProfessionalRelationshipsService _relationships;

  @override
  Stream<bool> watchProfessionalPremium(String professionalId) {
    return _firestore.collection('users').doc(professionalId).snapshots().map(
      (snapshot) => normalizePremiumEntitlement(
        snapshot.data()?['isPremium'],
      ),
    );
  }

  @override
  Stream<List<StudentSummary>> watchActiveStudents(String professionalId) {
    return _firestore
        .collection('users')
        .where(
          Filter.or(
            Filter('professorId', isEqualTo: professionalId),
            Filter('personalId', isEqualTo: professionalId),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UserModel.fromDocument)
              .map(_toStudentSummary)
              .toList(growable: false),
        );
  }

  @override
  Future<List<StudentSummary>> findCanonicalStudentsByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return const <StudentSummary>[];
    }

    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .get();

    return snapshot.docs
        .map(UserModel.fromDocument)
        .where(
          (candidate) =>
              candidate.isCanonicalIdentity && candidate.isAlunoMember,
        )
        .map(_toStudentSummary)
        .toList(growable: false);
  }

  @override
  Stream<List<PendingStudentInvite>> watchPendingInvites(
    String professionalId,
  ) {
    return _firestore
        .collection('invites')
        .where('personalId', isEqualTo: professionalId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => PendingStudentInvite(
                  id: document.id,
                  studentEmail: _stringOrFallback(
                    document.data()['toStudentEmail'],
                    'Email desconhecido',
                  ),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<StudentInviteCreationResult> createStudentInvite({
    required String studentId,
  }) async {
    final result = await _relationships.createStudentInvite(
      studentId: studentId,
    );

    return StudentInviteCreationResult.fromMap(result);
  }

  @override
  Future<void> unlinkStudent({required String studentId}) async {
    await _relationships.unlinkStudent(studentId: studentId);
  }

  @override
  Future<void> cancelStudentInvite({required String inviteId}) async {
    await _relationships.cancelStudentInvite(inviteId: inviteId);
  }

  static StudentSummary _toStudentSummary(UserModel user) {
    return StudentSummary(
      id: user.id,
      name: user.name,
      email: user.email,
      photoUrl: user.photoUrl,
      professorId: user.professorId,
    );
  }

  static String _stringOrFallback(dynamic value, String fallback) {
    if (value is! String) return fallback;

    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

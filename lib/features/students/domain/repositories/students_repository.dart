import '../entities/pending_student_invite.dart';
import '../entities/student_invite_creation_result.dart';
import '../entities/student_summary.dart';

abstract interface class StudentsRepository {
  Stream<bool> watchProfessionalPremium(String professionalId);

  Stream<List<StudentSummary>> watchActiveStudents(String professionalId);

  Future<List<StudentSummary>> findCanonicalStudentsByEmail(String email);

  Stream<List<PendingStudentInvite>> watchPendingInvites(
    String professionalId,
  );

  Future<StudentInviteCreationResult> createStudentInvite({
    required String studentId,
  });

  Future<void> unlinkStudent({required String studentId});

  Future<void> cancelStudentInvite({required String inviteId});
}

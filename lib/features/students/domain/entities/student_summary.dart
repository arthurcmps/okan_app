class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.professorId,
  });

  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? professorId;
}

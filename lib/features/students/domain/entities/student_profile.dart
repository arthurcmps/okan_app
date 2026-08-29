class StudentProfile {
  const StudentProfile({
    required this.photoUrl,
    required this.birthDate,
    required this.gender,
  });

  final String? photoUrl;
  final DateTime? birthDate;
  final String gender;
}

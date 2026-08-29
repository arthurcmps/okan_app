class StudentInviteCreationResult {
  const StudentInviteCreationResult({
    required this.alreadyPending,
  });

  factory StudentInviteCreationResult.fromMap(Map<String, dynamic> map) {
    return StudentInviteCreationResult(
      alreadyPending: map['alreadyPending'] == true,
    );
  }

  final bool alreadyPending;
}

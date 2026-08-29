class StudentRelationshipException implements Exception {
  const StudentRelationshipException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  bool get isPlanLimit => code == 'resource-exhausted';

  @override
  String toString() => 'StudentRelationshipException($code): $message';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('reads canonical User v2', () {
      final createdAt = DateTime.utc(2026, 1, 10);
      final updatedAt = DateTime.utc(2026, 2, 10);

      final user = UserModel.fromMap({
        'schemaVersion': 2,
        'uid': 'user-1',
        'name': 'Usuário Teste',
        'email': 'teste@example.com',
        'role': 'professor',
        'photoUrl': 'https://example.com/photo.jpg',
        'academyId': 'academy-1',
        'professorId': null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      }, 'user-1');

      expect(user.uid, 'user-1');
      expect(user.schemaVersion, 2);
      expect(user.name, 'Usuário Teste');
      expect(user.email, 'teste@example.com');
      expect(user.role, UserRoles.professor);
      expect(user.academyId, 'academy-1');
      expect(user.createdAt, createdAt);
      expect(user.updatedAt, updatedAt);
      expect(user.isV2, isTrue);
    });

    test('reads legacy Portuguese field names', () {
      final createdAt = DateTime.utc(2025, 5, 1);

      final user = UserModel.fromMap({
        'nome': 'Usuário Legado',
        'email': 'legado@example.com',
        'tipo': 'personal',
        'academiaId': 'academy-old',
        'personalId': 'personal-old',
        'criadoEm': Timestamp.fromDate(createdAt),
      }, 'legacy-1');

      expect(user.uid, 'legacy-1');
      expect(user.schemaVersion, 1);
      expect(user.name, 'Usuário Legado');
      expect(user.role, UserRoles.professor);
      expect(user.academyId, 'academy-old');
      expect(user.professorId, 'personal-old');
      expect(user.createdAt, createdAt);
    });

    test('canonical role wins over conflicting tipo', () {
      final user = UserModel.fromMap({
        'email': 'admin@example.com',
        'role': 'super_admin',
        'tipo': 'aluno',
      }, 'admin-1');

      expect(user.role, UserRoles.superAdmin);
    });

    test('legacy personal role becomes professor', () {
      final user = UserModel.fromMap({
        'email': 'personal@example.com',
        'role': 'personal',
      }, 'personal-1');

      expect(user.role, UserRoles.professor);
    });

    test('student markers safely resolve missing role as aluno', () {
      final user = UserModel.fromMap({
        'email': 'aluno@example.com',
        'weight': 80,
        'personalId': 'professor-1',
      }, 'student-1');

      expect(user.role, UserRoles.aluno);
    });

    test('document id is source of truth for uid', () {
      final user = UserModel.fromMap({
        'uid': 'wrong-uid',
        'email': 'teste@example.com',
        'role': 'aluno',
      }, 'correct-document-id');

      expect(user.uid, 'correct-document-id');
    });

    test('toMap writes only canonical User v2 fields', () {
      final user = UserModel(
        id: 'user-1',
        uid: 'user-1',
        schemaVersion: 1,
        name: 'Usuário',
        email: 'teste@example.com',
        role: UserRoles.professor,
        academyId: 'academy-1',
        professorId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final map = user.toMap();

      expect(map['schemaVersion'], 2);
      expect(map['uid'], 'user-1');
      expect(map['role'], 'professor');
      expect(map['academyId'], 'academy-1');

      expect(map.containsKey('tipo'), isFalse);
      expect(map.containsKey('nome'), isFalse);
      expect(map.containsKey('academiaId'), isFalse);
      expect(map.containsKey('personalId'), isFalse);
      expect(map.containsKey('age'), isFalse);
      expect(map.containsKey('weight'), isFalse);
      expect(map.containsKey('objectives'), isFalse);
    });
    test('unknown user without markers remains unresolved', () {
      final user = UserModel.fromMap({
        'email': 'unknown@example.com',
      }, 'unknown-1');

      expect(user.role, UserRoles.unresolved);
      expect(user.isAluno, isFalse);
      expect(user.isProfessor, isFalse);
      expect(user.isGymAdmin, isFalse);
      expect(user.isSuperAdmin, isFalse);
    });
  });
}

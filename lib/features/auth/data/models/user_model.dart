import 'package:cloud_firestore/cloud_firestore.dart';

/// Papéis canônicos definidos pelo User Schema v2.
abstract final class UserRoles {
  static const String aluno = 'aluno';
  static const String professor = 'professor';
  static const String gymAdmin = 'gym_admin';
  static const String superAdmin = 'super_admin';
  static const String unresolved = 'unresolved';

  static const Set<String> canonical = {aluno, professor, gymAdmin, superAdmin};
}

/// Representação compatível do documento:
///
/// users/{uid}
///
/// Durante a Fase 4 este model consegue LER tanto documentos legados
/// quanto documentos User Schema v2.
///
/// Ao serializar, porém, escreve somente os nomes canônicos do v2.
class UserModel {
  static const int currentSchemaVersion = 2;

  /// ID do documento Firestore.
  final String id;

  /// UID canônico.
  ///
  /// O ID do documento é sempre considerado a fonte de verdade.
  final String uid;

  final int schemaVersion;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;
  final String? academyId;
  final String? professorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.uid,
    required this.schemaVersion,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.academyId,
    this.professorId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isV2 => schemaVersion >= currentSchemaVersion;

  bool get isAluno => role == UserRoles.aluno;

  bool get isProfessor => role == UserRoles.professor;

  bool get isGymAdmin => role == UserRoles.gymAdmin;

  bool get isSuperAdmin => role == UserRoles.superAdmin;

  /// Identidade já convertida para o contrato User v2.
  ///
  /// Registros legados preservados por segurança não devem
  /// participar de novas buscas de usuários.
  bool get isCanonicalIdentity => isV2 && UserRoles.canonical.contains(role);

  /// Usuários autorizados a atuar na gestão de treinos.
  ///
  /// Super admin já possuía essa capacidade nas telas legadas.
  bool get isTrainingProfessional => isProfessor || isSuperAdmin;

  /// Converte documento Firestore/Map para UserModel.
  ///
  /// Compatibilidades suportadas:
  ///
  /// name <- name | nome
  /// role <- role | tipo
  /// personal -> professor
  /// academyId <- academyId | academiaId
  /// professorId <- professorId | personalId
  /// createdAt <- createdAt | criadoEm
  /// updatedAt <- updatedAt | lastUpdate | createdAt
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final createdAt = _dateFrom(map['createdAt']) ?? _dateFrom(map['criadoEm']);

    final updatedAt =
        _dateFrom(map['updatedAt']) ??
        _dateFrom(map['lastUpdate']) ??
        createdAt;

    return UserModel(
      id: documentId,

      // O documentId é a fonte canônica de verdade.
      // Não confiamos em um eventual uid divergente no payload.
      uid: documentId,

      schemaVersion: _schemaVersionFrom(map['schemaVersion']),

      name: _stringFrom(map['name']) ?? _stringFrom(map['nome']) ?? '',

      email: _stringFrom(map['email']) ?? '',

      role: _resolveRole(map),

      photoUrl: _stringFrom(map['photoUrl']),

      academyId:
          _stringFrom(map['academyId']) ?? _stringFrom(map['academiaId']),

      professorId:
          _stringFrom(map['professorId']) ?? _stringFrom(map['personalId']),

      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Atalho para converter diretamente um DocumentSnapshot.
  factory UserModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return UserModel.fromMap(
      document.data() ?? <String, dynamic>{},
      document.id,
    );
  }

  /// Serialização canônica User Schema v2.
  ///
  /// Nenhum campo legado como `tipo`, `nome`, `personalId`
  /// ou `academiaId` é escrito por este método.
  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': currentSchemaVersion,
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'academyId': academyId,
      'professorId': professorId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static int _schemaVersionFrom(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    // Documentos anteriores ao schemaVersion são tratados
    // como versão 1 durante a transição.
    return 1;
  }

  static String? _stringFrom(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    return null;
  }

  static String _resolveRole(Map<String, dynamic> map) {
    final role = _stringFrom(map['role'])?.toLowerCase();

    // Role canônico sempre vence o campo legado `tipo`.
    if (role != null) {
      if (UserRoles.canonical.contains(role)) {
        return role;
      }

      if (role == 'personal') {
        return UserRoles.professor;
      }
    }

    final tipo = _stringFrom(map['tipo'])?.toLowerCase();

    if (tipo == 'personal') {
      return UserRoles.professor;
    }

    if (tipo == 'aluno') {
      return UserRoles.aluno;
    }

    // Documento legado sem role/tipo, mas com indicadores
    // claramente associados ao perfil de aluno.
    if (_hasStudentMarkers(map)) {
      return UserRoles.aluno;
    }

    // Fallback deliberadamente de menor privilégio.
    //
    // Nunca inferimos professor, gym_admin ou super_admin.
    return UserRoles.unresolved;
  }

  static bool _hasStudentMarkers(Map<String, dynamic> map) {
    const studentMarkers = {
      'personalId',
      'professorId',
      'peso',
      'weight',
      'altura',
      'objetivo',
      'objectives',
      'birthDate',
      'dataNascimento',
    };

    return studentMarkers.any(map.containsKey);
  }
}

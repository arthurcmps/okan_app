import 'package:cloud_firestore/cloud_firestore.dart';

/// Papéis canônicos definidos pelo User Schema v2.
///
/// `role` representa autorização/RBAC. Ele não deve ser usado para inferir
/// automaticamente a persona funcional do usuário no aplicativo.
abstract final class UserRoles {
  static const String aluno = 'aluno';
  static const String professor = 'professor';
  static const String gymAdmin = 'gym_admin';
  static const String superAdmin = 'super_admin';
  static const String unresolved = 'unresolved';

  static const Set<String> canonical = {aluno, professor, gymAdmin, superAdmin};
}

/// Personas funcionais do aplicativo mobile.
///
/// Um usuário pode, por exemplo, ter `role=super_admin` e ainda usar o app
/// como aluno ou professor. Por isso `memberType` é independente de `role`.
abstract final class UserMemberTypes {
  static const String aluno = 'aluno';
  static const String professor = 'professor';

  static const Set<String> canonical = {aluno, professor};
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

  /// Autorização/RBAC.
  final String role;

  /// Persona funcional do aplicativo mobile.
  final String? memberType;

  final String? photoUrl;
  final String? academyId;

  /// Relação canônica aluno -> professor.
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
    this.memberType,
    this.photoUrl,
    this.academyId,
    this.professorId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isV2 => schemaVersion >= currentSchemaVersion;

  /// Checks de RBAC.
  bool get isAluno => role == UserRoles.aluno;
  bool get isProfessor => role == UserRoles.professor;
  bool get isGymAdmin => role == UserRoles.gymAdmin;
  bool get isSuperAdmin => role == UserRoles.superAdmin;

  /// Checks da persona funcional mobile.
  bool get isAlunoMember => memberType == UserMemberTypes.aluno;
  bool get isProfessorMember => memberType == UserMemberTypes.professor;
  bool get hasMobilePersona => memberType != null;

  /// Identidade já convertida para o contrato User v2.
  ///
  /// Registros legados preservados por segurança não devem
  /// participar de novas buscas de usuários.
  bool get isCanonicalIdentity => isV2 && UserRoles.canonical.contains(role);

  /// Usuário que atua como professor no aplicativo mobile.
  ///
  /// Não inferimos essa capacidade apenas por `role=super_admin`, pois
  /// administradores podem usar o aplicativo com persona de aluno.
  bool get isTrainingProfessional => isProfessorMember;

  /// Converte documento Firestore/Map para UserModel.
  ///
  /// Compatibilidades suportadas:
  ///
  /// name <- name | nome
  /// role <- role | tipo
  /// memberType <- memberType | tipo | role comum
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

      memberType: _resolveMemberType(map),

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
      'memberType': memberType,
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

    // Nunca inferimos professor, gym_admin ou super_admin.
    return UserRoles.unresolved;
  }

  static String? _resolveMemberType(Map<String, dynamic> map) {
    final memberType = _stringFrom(map['memberType'])?.toLowerCase();

    // O campo canônico sempre tem precedência sobre `tipo`.
    if (memberType != null && UserMemberTypes.canonical.contains(memberType)) {
      return memberType;
    }

    final tipo = _stringFrom(map['tipo'])?.toLowerCase();

    // No app legado, `personal` representa a persona professor.
    if (tipo == 'personal') {
      return UserMemberTypes.professor;
    }

    if (tipo == 'aluno') {
      return UserMemberTypes.aluno;
    }

    // Para usuários comuns, role pode fornecer a persona durante a transição.
    // Roles administrativas não recebem persona implicitamente.
    final role = _resolveRole(map);

    if (role == UserRoles.aluno) {
      return UserMemberTypes.aluno;
    }

    if (role == UserRoles.professor) {
      return UserMemberTypes.professor;
    }

    return null;
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

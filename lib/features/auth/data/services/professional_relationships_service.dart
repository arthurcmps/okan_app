import 'package:cloud_functions/cloud_functions.dart';

const professionalRelationshipsRegion = 'southamerica-east1';

class ProfessionalRelationshipsService {
  ProfessionalRelationshipsService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: professionalRelationshipsRegion);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> createStudentInvite({
    required String studentId,
  }) {
    return _call(
      'createStudentInvite',
      <String, dynamic>{'studentId': studentId},
    );
  }

  Future<Map<String, dynamic>> respondStudentInvite({
    required String inviteId,
    required bool accept,
  }) {
    return _call(
      'respondStudentInvite',
      <String, dynamic>{
        'inviteId': inviteId,
        'response': accept ? 'accepted' : 'rejected',
      },
    );
  }

  Future<Map<String, dynamic>> cancelStudentInvite({
    required String inviteId,
  }) {
    return _call(
      'cancelStudentInvite',
      <String, dynamic>{'inviteId': inviteId},
    );
  }

  Future<Map<String, dynamic>> unlinkStudent({
    required String studentId,
  }) {
    return _call(
      'unlinkStudent',
      <String, dynamic>{'studentId': studentId},
    );
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final result = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data);
  }
}

bool isProfessionalRelationshipPlanLimit(Object error) {
  return error is FirebaseFunctionsException && error.code == 'resource-exhausted';
}

String professionalRelationshipErrorMessage(Object error) {
  if (error is! FirebaseFunctionsException) {
    return 'Não foi possível concluir esta ação agora. Tente novamente em instantes.';
  }

  switch (error.code) {
    case 'resource-exhausted':
      return 'Seu Plano Base atingiu o limite de alunos e convites pendentes.';
    case 'permission-denied':
      return 'Você não tem permissão para alterar este vínculo.';
    case 'failed-precondition':
      return 'Este vínculo não pode ser alterado no estado atual.';
    case 'not-found':
      return 'O convite, aluno ou professor não foi encontrado.';
    case 'invalid-argument':
      return 'Os dados enviados para esta ação são inválidos.';
    case 'unauthenticated':
      return 'Sua sessão expirou. Entre novamente para continuar.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Não foi possível concluir esta ação agora. Tente novamente em instantes.';
  }
}

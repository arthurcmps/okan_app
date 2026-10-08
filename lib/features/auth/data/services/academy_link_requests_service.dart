import 'package:cloud_functions/cloud_functions.dart';

const academyLinkRequestsRegion = 'southamerica-east1';

class AcademyLinkRequestsService {
  AcademyLinkRequestsService({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: academyLinkRequestsRegion);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> listMyAcademyLinkRequests({String? cursor}) {
    return _call('listMyAcademyLinkRequests', <String, dynamic>{
      if (cursor != null) 'cursor': cursor,
    });
  }

  Future<Map<String, dynamic>> respondStudentLink({
    required String requestId,
    required bool accept,
  }) {
    return _call('respondStudentLink', <String, dynamic>{
      'requestId': requestId,
      'response': accept ? 'accepted' : 'rejected',
    });
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final result = await callable.call(payload);
    final data = result.data;

    if (data is! Map) {
      throw StateError(
        'Resposta inválida do serviço de solicitações da academia.',
      );
    }

    return Map<String, dynamic>.from(data);
  }
}

String academyLinkRequestErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente para continuar.';
      case 'permission-denied':
        return 'Você não tem permissão para realizar esta ação.';
      case 'not-found':
        return 'A solicitação não foi encontrada.';
      case 'failed-precondition':
        return 'Esta ação não está disponível. '
            'Atualize a lista e confira o estado da solicitação.';
      case 'invalid-argument':
        return 'Os dados enviados são inválidos.';
      case 'resource-exhausted':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Não foi possível conectar ao serviço. '
            'Confira sua conexão e tente novamente.';
    }
  }

  return 'Não foi possível concluir esta ação agora. '
      'Tente novamente em instantes.';
}

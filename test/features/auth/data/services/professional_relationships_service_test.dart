import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/data/services/professional_relationships_service.dart';

void main() {
  test('usa a mesma regiao das callables de relacionamento', () {
    expect(professionalRelationshipsRegion, 'southamerica-east1');
  });

  test('mapeia limite do plano base', () {
    expect(
      professionalRelationshipMessageForCode('resource-exhausted'),
      'Seu Plano Base atingiu o limite de alunos e convites pendentes.',
    );
  });

  test('mapeia erros de autorizacao e estado', () {
    expect(
      professionalRelationshipMessageForCode('permission-denied'),
      'Você não tem permissão para alterar este vínculo.',
    );
    expect(
      professionalRelationshipMessageForCode('failed-precondition'),
      'Este vínculo não pode ser alterado no estado atual.',
    );
  });

  test('preserva mensagem sanitizada do backend para codigo desconhecido', () {
    expect(
      professionalRelationshipMessageForCode(
        'internal',
        fallbackMessage: 'Falha sanitizada.',
      ),
      'Falha sanitizada.',
    );
  });

  test('usa mensagem generica sem fallback', () {
    expect(
      professionalRelationshipMessageForCode('internal'),
      'Não foi possível concluir esta ação agora. Tente novamente em instantes.',
    );
  });
}

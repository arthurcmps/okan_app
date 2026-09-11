import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/arena/data/repositories/firebase_arena_repository.dart';

void main() {
  test('normaliza o placar agregado devolvido pela callable', () {
    final ranking = parseArenaRankingResponse({
      'ranking': [
        {
          'userId': 'student-2',
          'name': 'Atleta Dois',
          'photoUrl': 'https://example.test/photo.png',
          'delta': 12,
        },
        {
          'userId': 'student-1',
          'name': 'Atleta Um',
          'photoUrl': null,
          'delta': '3,5',
        },
      ],
    });

    expect(ranking, hasLength(2));
    expect(ranking.first.userId, 'student-2');
    expect(ranking.first.name, 'Atleta Dois');
    expect(ranking.first.delta, 12);
    expect(ranking.first.photoUrl, 'https://example.test/photo.png');
    expect(ranking.last.delta, 3.5);
    expect(ranking.last.photoUrl, isNull);
  });

  test('recusa resposta sem a lista agregada', () {
    expect(
      () => parseArenaRankingResponse({'unexpected': true}),
      throwsStateError,
    );
  });

  test('recusa participante sem identificador', () {
    expect(
      () => parseArenaRankingResponse({
        'ranking': [
          {'name': 'Atleta sem ID', 'delta': 1},
        ],
      }),
      throwsStateError,
    );
  });
}

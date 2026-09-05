import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/auth/presentation/pages/home_page.dart',
  ).readAsStringSync();

  test('persona actions appear before generic and beta resources', () {
    final workoutIndex = source.indexOf('"TREINO DE HOJE"');
    final personaIndex = source.indexOf("isProfessor ? 'GESTÃO DO DIA'");
    final quickMenuIndex = source.indexOf('"MENU RÁPIDO"');
    final betaIndex = source.indexOf('"FASE DE TESTES"');

    expect(workoutIndex, greaterThanOrEqualTo(0));
    expect(personaIndex, greaterThan(workoutIndex));
    expect(quickMenuIndex, greaterThan(personaIndex));
    expect(betaIndex, greaterThan(quickMenuIndex));
  });

  test('persona destinations remain unchanged', () {
    final expectedContracts = <String, String>{
      'title: "Meus Alunos"': 'const StudentsPage()',
      'title: "Meu Personal"': 'ChatPage(',
      'title: "Arena Okan ⚔️"': 'const ArenaPage()',
      'title: "Metas"': 'const TarefasPage()',
      'title: "Semana"': 'WeeklyPlanPage(',
    };

    for (final entry in expectedContracts.entries) {
      final titleIndex = source.indexOf(entry.key);
      final destinationIndex = source.indexOf(entry.value, titleIndex);

      expect(titleIndex, greaterThanOrEqualTo(0), reason: entry.key);
      expect(destinationIndex, greaterThan(titleIndex), reason: entry.value);
      expect(
        destinationIndex - titleIndex,
        lessThan(700),
        reason: '${entry.key} deve continuar ligado a ${entry.value}',
      );
    }
  });

  test('reordering does not add another users stream', () {
    expect(".collection('users')".allMatches(source).length, 3);
  });

  test('users without a mobile persona do not see an empty section', () {
    expect(source, contains('if (!isProfessor && !isAluno)'));
    expect(source, contains('return const SizedBox.shrink();'));
  });
}

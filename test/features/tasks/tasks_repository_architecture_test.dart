import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TarefaController usa TasksRepository sem Firestore direto', () {
    final source = File(
      'lib/features/auth/presentation/controllers/tarefa_controller.dart',
    ).readAsStringSync();

    expect(source, contains('TasksRepository'));
    expect(source, contains('FirebaseTasksRepository'));
    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('FirebaseFirestore')));
  });

  test('entidade de Tasks nao depende de Firebase', () {
    final source = File(
      'lib/features/tasks/domain/entities/task_item.dart',
    ).readAsStringSync();

    expect(source, contains('class Tarefa'));
    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('Timestamp')));
  });
}

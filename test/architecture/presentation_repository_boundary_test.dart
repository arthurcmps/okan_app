import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _legacyInfrastructureExceptions = <String>{
  'lib/features/auth/presentation/pages/professor_subscription_page.dart',
};

void main() {
  test('presentation nao introduz novos acessos diretos ao Firestore', () {
    final presentationFiles = _presentationFiles();

    expect(presentationFiles, isNotEmpty);

    for (final file in presentationFiles) {
      final relativePath = _relativePath(file.path);
      final source = file.readAsStringSync();

      if (_legacyInfrastructureExceptions.contains(relativePath)) {
        continue;
      }

      expect(
        source,
        isNot(contains('package:cloud_firestore/cloud_firestore.dart')),
        reason: '$relativePath importa Firestore diretamente',
      );
      expect(
        source,
        isNot(contains('FirebaseFirestore')),
        reason: '$relativePath acessa Firestore diretamente',
      );
      expect(
        source,
        isNot(contains('FirebaseFunctions.instance')),
        reason: '$relativePath instancia Functions diretamente',
      );
    }
  });

  test('excecoes legadas de infraestrutura permanecem explicitas', () {
    final existing = _presentationFiles()
        .map((file) => _relativePath(file.path))
        .toSet();

    for (final exception in _legacyInfrastructureExceptions) {
      expect(
        existing,
        contains(exception),
        reason: 'Remova $exception da allowlist quando a migracao terminar.',
      );
    }
  });

  test('fatias migradas usam repository boundaries', () {
    const migratedPresentation = <String, String>{
      'lib/features/auth/presentation/pages/students_page.dart':
          'StudentsRepository',
      'lib/features/auth/presentation/pages/chat_page.dart':
          'ChatRepository',
      'lib/features/auth/presentation/pages/notifications_page.dart':
          'NotificationsRepository',
      'lib/features/auth/presentation/controllers/tarefa_controller.dart':
          'TasksRepository',
    };

    for (final entry in migratedPresentation.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains(entry.value));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('cloud_firestore')));
    }
  });
}

List<File> _presentationFiles() {
  final featuresDirectory = Directory('lib/features');

  return featuresDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('.dart') &&
            file.path.replaceAll('\\', '/').contains('/presentation/'),
      )
      .toList(growable: false);
}

String _relativePath(String path) {
  return path.replaceAll('\\', '/');
}

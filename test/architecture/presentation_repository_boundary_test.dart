import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _legacyInfrastructureExceptions = <String, String>{
  'lib/features/auth/presentation/pages/anamnese_tab.dart': 'OKAN-033',
  'lib/features/auth/presentation/pages/arena_page.dart': 'OKAN-034',
  'lib/features/auth/presentation/pages/assessments_tab.dart': 'OKAN-033',
  'lib/features/auth/presentation/pages/create_workout_page.dart': 'OKAN-031',
  'lib/features/auth/presentation/pages/discover_workouts_page.dart':
      'OKAN-031 / OKAN-034',
  'lib/features/auth/presentation/pages/evolution_charts_page.dart':
      'OKAN-031 / OKAN-033',
  'lib/features/auth/presentation/pages/home_page.dart':
      'Fase 6 - composicao das features',
  'lib/features/auth/presentation/pages/library_admin_page.dart': 'OKAN-034',
  'lib/features/auth/presentation/pages/manage_workouts_page.dart': 'OKAN-031',
  'lib/features/auth/presentation/pages/personal_data_page.dart':
      'Profile/Auth follow-up',
  'lib/features/auth/presentation/pages/professor_subscription_page.dart':
      'Subscriptions / pagamentos',
  'lib/features/auth/presentation/pages/profile_page.dart':
      'Profile/Auth follow-up',
  'lib/features/auth/presentation/pages/register_page.dart': 'Auth follow-up',
  'lib/features/auth/presentation/pages/student_detail_page.dart': 'OKAN-032',
  'lib/features/auth/presentation/pages/super_admin_page.dart': 'OKAN-034',
  'lib/features/auth/presentation/pages/weekly_plan_page.dart': 'OKAN-031',
  'lib/features/auth/presentation/pages/workout_history_page.dart': 'OKAN-031',
};

void main() {
  test('presentation nao introduz novos acessos diretos ao Firebase', () {
    final presentationFiles = _presentationFiles();

    expect(presentationFiles, isNotEmpty);

    final unexpected = <String>[];

    for (final file in presentationFiles) {
      final relativePath = _relativePath(file.path);
      final source = file.readAsStringSync();

      if (!_usesDirectFirebaseInfrastructure(source)) {
        continue;
      }

      if (!_legacyInfrastructureExceptions.containsKey(relativePath)) {
        unexpected.add(relativePath);
      }
    }

    expect(
      unexpected,
      isEmpty,
      reason: unexpected.isEmpty
          ? null
          : 'Novos acessos diretos ao Firebase em presentation:\n'
                '${unexpected.map((path) => ' - $path').join('\n')}',
    );
  });

  test('baseline legado permanece explicito e removivel', () {
    final existing = _presentationFiles()
        .map((file) => _relativePath(file.path))
        .toSet();

    for (final entry in _legacyInfrastructureExceptions.entries) {
      expect(
        existing,
        contains(entry.key),
        reason: '${entry.key} deixou de existir; remova do baseline.',
      );

      final source = File(entry.key).readAsStringSync();
      expect(
        _usesDirectFirebaseInfrastructure(source),
        isTrue,
        reason:
            '${entry.key} ja nao usa Firebase diretamente. '
            'Remova a excecao (${entry.value}) do baseline.',
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
      expect(source, isNot(contains('FirebaseFunctions.instance')));
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('cloud_functions')));
    }
  });
}

bool _usesDirectFirebaseInfrastructure(String source) {
  return source.contains('FirebaseFirestore') ||
      source.contains('FirebaseFunctions.instance');
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

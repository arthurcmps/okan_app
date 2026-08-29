import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout domain remains Firebase-free', () {
    final domain = Directory('lib/features/workouts/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in domain) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')));
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('Timestamp')));
      expect(source, isNot(contains('FieldValue')));
    }
  });

  test('migrated workout presentation depends on WorkoutsRepository', () {
    const files = <String>[
      'lib/features/workouts/presentation/pages/create_workout_page.dart',
      'lib/features/workouts/presentation/pages/manage_workouts_page.dart',
      'lib/features/workouts/presentation/pages/train_page.dart',
      'lib/features/workouts/presentation/pages/weekly_plan_page.dart',
      'lib/features/workouts/presentation/pages/workout_history_page.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('WorkoutsRepository'), reason: path);
      expect(source, isNot(contains('cloud_firestore')), reason: path);
      expect(source, isNot(contains('FirebaseFirestore')), reason: path);
      expect(source, isNot(contains('FirebaseFunctions.instance')), reason: path);
    }
  });

  test('legacy auth workout paths are compatibility exports', () {
    const compatibility = <String>[
      'lib/features/auth/data/models/workout_plans_model.dart',
      'lib/features/auth/data/models/workout_history_model.dart',
      'lib/features/auth/presentation/pages/create_workout_page.dart',
      'lib/features/auth/presentation/pages/manage_workouts_page.dart',
      'lib/features/auth/presentation/pages/train_page.dart',
      'lib/features/auth/presentation/pages/weekly_plan_page.dart',
      'lib/features/auth/presentation/pages/workout_history_page.dart',
    ];

    for (final path in compatibility) {
      final source = File(path).readAsStringSync().trim();
      expect(source, startsWith('export '), reason: path);
    }
  });

  test('weekly plan infrastructure stays behind repository contract', () {
    final contract = File(
      'lib/features/workouts/domain/repositories/workouts_repository.dart',
    ).readAsStringSync();

    for (final member in <String>[
      'watchWeeklyPlan',
      'saveWorkoutDay',
      'saveWorkoutFeedback',
      'setWorkoutValidity',
      'watchWorkoutTemplates',
      'notifyUser',
    ]) {
      expect(contract, contains(member));
    }
  });
}

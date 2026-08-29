import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Store domain remains Firebase-free', () {
    final files = Directory('lib/features/store/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('cloud_firestore')), reason: file.path);
      expect(source, isNot(contains('cloud_functions')), reason: file.path);
      expect(source, isNot(contains('firebase_auth')), reason: file.path);
      expect(source, isNot(contains('Timestamp')), reason: file.path);
      expect(source, isNot(contains('FieldValue')), reason: file.path);
    }
  });

  test('Store presentation delegates infrastructure to StoreRepository', () {
    for (final path in <String>[
      'lib/features/store/presentation/pages/discover_workouts_page.dart',
      'lib/features/store/presentation/pages/library_admin_page.dart',
      'lib/features/store/presentation/pages/super_admin_page.dart',
      'lib/features/store/presentation/widgets/template_checkout_sheet.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('StoreRepository'), reason: path);
      expect(source, isNot(contains('cloud_firestore')), reason: path);
      expect(source, isNot(contains('cloud_functions')), reason: path);
      expect(source, isNot(contains('firebase_auth')), reason: path);
      expect(source, isNot(contains('FirebaseFirestore')), reason: path);
      expect(source, isNot(contains('FirebaseFunctions.instance')), reason: path);
      expect(source, isNot(contains('api.mercadopago.com')), reason: path);
    }
  });

  test('Store Firebase and payment contracts live in data repository', () {
    final source = File(
      'lib/features/store/data/repositories/firebase_store_repository.dart',
    ).readAsStringSync();
    for (final contract in <String>[
      "collection('exercises')",
      "collection('workout_templates')",
      'adquirirTemplateGratuito',
      'criarPagamentoPix',
      'criarPagamentoCartao',
      'api.mercadopago.com',
    ]) {
      expect(source, contains(contract), reason: contract);
    }
  });

  test('Store discovery preserves WorkoutsRepository application boundary', () {
    final source = File(
      'lib/features/store/presentation/pages/discover_workouts_page.dart',
    ).readAsStringSync();
    expect(source, contains('WorkoutsRepository'));
    expect(source, contains('appendWorkoutDays'));
    expect(source, isNot(contains("collection('workout_plans')")));
  });

  test('legacy Store paths are compatibility exports', () {
    for (final path in <String>[
      'lib/features/auth/presentation/pages/discover_workouts_page.dart',
      'lib/features/auth/presentation/pages/library_admin_page.dart',
      'lib/features/auth/presentation/pages/super_admin_page.dart',
    ]) {
      final source = File(path).readAsStringSync().trim();
      expect(source, startsWith('export '), reason: path);
    }
  });
}

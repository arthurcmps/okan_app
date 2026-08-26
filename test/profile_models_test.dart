import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/auth/data/models/fitness_profile_model.dart';
import 'package:okan_app/features/auth/data/models/private_profile_model.dart';

void main() {
  group('PrivateProfileModel', () {
    test('reads canonical private profile', () {
      final birthDate = DateTime.utc(1995, 4, 10);
      final updatedAt = DateTime.utc(2026, 8, 1);

      final profile = PrivateProfileModel.fromMap({
        'birthDate': Timestamp.fromDate(birthDate),
        'gender': 'masculino',
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(profile.birthDate, birthDate);
      expect(profile.gender, 'masculino');
      expect(profile.updatedAt, updatedAt);
    });

    test('reads legacy private profile fields', () {
      final birthDate = DateTime.utc(1990, 2, 20);
      final updatedAt = DateTime.utc(2026, 7, 1);

      final profile = PrivateProfileModel.fromLegacyUserMap({
        'dataNascimento': Timestamp.fromDate(birthDate),
        'gender': 'masculino',
        'lastUpdate': Timestamp.fromDate(updatedAt),
      });

      expect(profile.birthDate, birthDate);
      expect(profile.gender, 'masculino');
      expect(profile.updatedAt, updatedAt);
    });

    test('toMap writes canonical private fields', () {
      final birthDate = DateTime.utc(1993, 8, 11);

      final profile = PrivateProfileModel(
        birthDate: birthDate,
        gender: 'masculino',
      );

      final map = profile.toMap();

      expect(map.containsKey('birthDate'), isTrue);
      expect(map.containsKey('gender'), isTrue);

      expect(map.containsKey('dataNascimento'), isFalse);

      expect(map.containsKey('age'), isFalse);
    });
  });

  group('FitnessProfileModel', () {
    test('reads canonical fitness profile', () {
      final updatedAt = DateTime.utc(2026, 8, 1);

      final profile = FitnessProfileModel.fromMap({
        'weightKg': 82.5,
        'heightCm': 175.0,
        'objective': 'Hipertrofia',
        'weeklyFrequency': 4,
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(profile.weightKg, 82.5);
      expect(profile.heightCm, 175);
      expect(profile.objective, 'Hipertrofia');
      expect(profile.weeklyFrequency, 4);
      expect(profile.updatedAt, updatedAt);
      expect(profile.legacyWeightConflict, isFalse);
    });

    test('normalizes legacy fitness values', () {
      final profile = FitnessProfileModel.fromLegacyUserMap({
        'peso': '80,5',
        'altura': '1.75',
        'objetivo': 'Emagrecer',
        'freq_semanal': '3x',
      });

      expect(profile.weightKg, 80.5);
      expect(profile.heightCm, 175);
      expect(profile.objective, 'Emagrecer');
      expect(profile.weeklyFrequency, 3);
      expect(profile.legacyWeightConflict, isFalse);
    });

    test('legacy placeholders become null', () {
      final profile = FitnessProfileModel.fromLegacyUserMap({
        'peso': '--',
        'altura': '--',
        'objetivo': '--',
        'freq_semanal': '--',
      });

      expect(profile.weightKg, isNull);
      expect(profile.heightCm, isNull);
      expect(profile.objective, isNull);
      expect(profile.weeklyFrequency, isNull);
    });

    test('detects conflicting legacy weights', () {
      final profile = FitnessProfileModel.fromLegacyUserMap({
        'peso': 80,
        'weight': 90,
      });

      expect(profile.weightKg, isNull);
      expect(profile.legacyWeightConflict, isTrue);
    });

    test('toMap writes only canonical fitness fields', () {
      const profile = FitnessProfileModel(
        weightKg: 80,
        heightCm: 175,
        objective: 'Condicionamento',
        weeklyFrequency: 4,
      );

      final map = profile.toMap();

      expect(map['weightKg'], 80);
      expect(map['heightCm'], 175);
      expect(map['objective'], 'Condicionamento');
      expect(map['weeklyFrequency'], 4);

      expect(map.containsKey('peso'), isFalse);
      expect(map.containsKey('altura'), isFalse);
      expect(map.containsKey('objetivo'), isFalse);
      expect(map.containsKey('freq_semanal'), isFalse);
      expect(map.containsKey('imc'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/assessments/domain/entities/physical_assessment.dart';

void main() {
  group('calculateBodyMassIndex', () {
    test('aceita altura em centimetros', () {
      expect(
        calculateBodyMassIndex(weight: 80, height: 180),
        24.69,
      );
    });

    test('aceita altura em metros', () {
      expect(
        calculateBodyMassIndex(weight: 80, height: 1.8),
        24.69,
      );
    });

    test('rejeita valores invalidos', () {
      expect(calculateBodyMassIndex(weight: null, height: 180), isNull);
      expect(calculateBodyMassIndex(weight: 80, height: 0), isNull);
      expect(calculateBodyMassIndex(weight: -1, height: 180), isNull);
    });
  });

  test('PhysicalAssessment normaliza valores numericos', () {
    final assessment = PhysicalAssessment(
      id: 'a1',
      date: DateTime(2026, 8, 29),
      values: const {
        'weight': 80,
        'bodyFatPercentage': '18,5',
        'invalid': 'abc',
      },
    );

    expect(assessment.numberValue('weight'), 80);
    expect(assessment.numberValue('bodyFatPercentage'), 18.5);
    expect(assessment.numberValue('invalid'), isNull);
  });
}

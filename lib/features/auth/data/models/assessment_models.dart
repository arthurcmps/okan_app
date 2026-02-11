// Modelo para Perimetria e Bioimpedância
class PhysicalAssessment {
  final String id;
  final DateTime date;
  final double weight;
  final double height;
  
  // Perimetria
  final double? neck;
  final double? shoulders;
  final double? chest;
  final double? waist;
  final double? abdomen;
  final double? hips;
  final double? armRightRelaxed;
  final double? armRightContracted;
  final double? armLeftRelaxed;
  final double? armLeftContracted;
  final double? forearmRight;
  final double? forearmLeft;
  final double? thighRight;
  final double? thighLeft;
  final double? calfRight;
  final double? calfLeft;

  // Bioimpedância
  final double? imc;
  final double? bodyFatPercentage;
  final double? fatMassKg;
  final double? muscleMassKg; // ou %
  final int? visceralFat;
  final double? basalMetabolism;
  final int? metabolicAge;
  final double? bodyWaterPercentage;
  final double? boneMass;

  PhysicalAssessment({
    required this.id,
    required this.date,
    required this.weight,
    required this.height,
    this.neck, this.shoulders, this.chest, this.waist, this.abdomen, this.hips,
    this.armRightRelaxed, this.armRightContracted, this.armLeftRelaxed, this.armLeftContracted,
    this.forearmRight, this.forearmLeft, this.thighRight, this.thighLeft,
    this.calfRight, this.calfLeft,
    this.imc, this.bodyFatPercentage, this.fatMassKg, this.muscleMassKg,
    this.visceralFat, this.basalMetabolism, this.metabolicAge,
    this.bodyWaterPercentage, this.boneMass,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
      'height': height,
      'neck': neck, 'shoulders': shoulders, 'chest': chest,
      'waist': waist, 'abdomen': abdomen, 'hips': hips,
      'armRightRelaxed': armRightRelaxed, 'armRightContracted': armRightContracted,
      'armLeftRelaxed': armLeftRelaxed, 'armLeftContracted': armLeftContracted,
      'forearmRight': forearmRight, 'forearmLeft': forearmLeft,
      'thighRight': thighRight, 'thighLeft': thighLeft,
      'calfRight': calfRight, 'calfLeft': calfLeft,
      'imc': imc, 'bodyFatPercentage': bodyFatPercentage,
      'fatMassKg': fatMassKg, 'muscleMassKg': muscleMassKg,
      'visceralFat': visceralFat, 'basalMetabolism': basalMetabolism,
      'metabolicAge': metabolicAge, 'bodyWaterPercentage': bodyWaterPercentage,
      'boneMass': boneMass,
    };
  }
}
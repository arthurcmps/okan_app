class PhysicalAssessment {
  final String id;
  final DateTime date;
  
  // --- DADOS BÁSICOS ---
  final double weight; // Peso Corporal
  final double height; // Altura

  // --- PERIMETRIA (MEDIDAS) ---
  final double? neck; // Pescoço
  final double? shoulders; // Ombros
  final double? chest; // Tórax
  final double? waist; // Cintura
  final double? abdomen; // Abdômen
  final double? hips; // Quadril
  
  // Membros Superiores
  final double? armRightRelaxed; // Braço Direito Relaxado
  final double? armRightContracted; // Braço Direito Contraído
  final double? armLeftRelaxed; // Braço Esquerdo Relaxado
  final double? armLeftContracted; // Braço Esquerdo Contraído
  final double? forearmRight; // Antebraço Direito
  final double? forearmLeft; // Antebraço Esquerdo
  
  // Membros Inferiores
  final double? thighRight; // Coxa Direita (Medial)
  final double? thighLeft; // Coxa Esquerda (Medial)
  final double? calfRight; // Panturrilha Direita
  final double? calfLeft; // Panturrilha Esquerda

  // --- BIOIMPEDÂNCIA ---
  final double? imc; // IMC (Calculado ou inserido)
  final double? bodyFatPercentage; // % Gordura Corporal
  final double? fatMassKg; // Massa Gorda (kg)
  final double? muscleMassKg; // Massa Muscular (kg ou %)
  final int? visceralFat; // Gordura Visceral (1-9)
  final double? basalMetabolism; // Taxa Metabólica Basal
  final int? metabolicAge; // Idade Metabólica
  final double? bodyWaterPercentage; // % Água Corporal
  final double? boneMass; // Massa Óssea (kg)
  final String? generalRating; // Avaliação Física Geral (Ruim/Bom/Ótimo)

  PhysicalAssessment({
    required this.id,
    required this.date,
    required this.weight,
    required this.height,
    this.neck, this.shoulders, this.chest, this.waist, this.abdomen, this.hips,
    this.armRightRelaxed, this.armRightContracted, this.armLeftRelaxed, this.armLeftContracted,
    this.forearmRight, this.forearmLeft, 
    this.thighRight, this.thighLeft,
    this.calfRight, this.calfLeft,
    this.imc, this.bodyFatPercentage, this.fatMassKg, this.muscleMassKg,
    this.visceralFat, this.basalMetabolism, this.metabolicAge,
    this.bodyWaterPercentage, this.boneMass, this.generalRating
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
      'height': height,
      // Perimetria
      'neck': neck, 'shoulders': shoulders, 'chest': chest,
      'waist': waist, 'abdomen': abdomen, 'hips': hips,
      'armRightRelaxed': armRightRelaxed, 'armRightContracted': armRightContracted,
      'armLeftRelaxed': armLeftRelaxed, 'armLeftContracted': armLeftContracted,
      'forearmRight': forearmRight, 'forearmLeft': forearmLeft,
      'thighRight': thighRight, 'thighLeft': thighLeft,
      'calfRight': calfRight, 'calfLeft': calfLeft,
      // Bioimpedância
      'imc': imc, 
      'bodyFatPercentage': bodyFatPercentage,
      'fatMassKg': fatMassKg, 
      'muscleMassKg': muscleMassKg,
      'visceralFat': visceralFat, 
      'basalMetabolism': basalMetabolism,
      'metabolicAge': metabolicAge, 
      'bodyWaterPercentage': bodyWaterPercentage,
      'boneMass': boneMass,
      'generalRating': generalRating,
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dados físicos atuais do usuário.
///
/// Caminho canônico:
/// users/{uid}/fitness/current
class FitnessProfileModel {
  final double? weightKg;
  final double? heightCm;
  final String? objective;
  final int? weeklyFrequency;
  final DateTime? updatedAt;

  /// Indica que o documento legado possuía `peso` e `weight`
  /// simultaneamente com valores diferentes.
  ///
  /// Esse conflito não deve ser resolvido silenciosamente.
  final bool legacyWeightConflict;

  const FitnessProfileModel({
    this.weightKg,
    this.heightCm,
    this.objective,
    this.weeklyFrequency,
    this.updatedAt,
    this.legacyWeightConflict = false,
  });

  /// Lê o formato canônico User v2.
  factory FitnessProfileModel.fromMap(Map<String, dynamic> map) {
    return FitnessProfileModel(
      weightKg: _numberFrom(map['weightKg']),
      heightCm: _numberFrom(map['heightCm']),
      objective: _stringFrom(map['objective']),
      weeklyFrequency: _frequencyFrom(map['weeklyFrequency']),
      updatedAt: _dateFrom(map['updatedAt']),
    );
  }

  /// Compatibilidade temporária com os campos legados
  /// atualmente existentes em users/{uid}.
  factory FitnessProfileModel.fromLegacyUserMap(Map<String, dynamic> map) {
    final peso = _numberFrom(map['peso']);
    final weight = _numberFrom(map['weight']);

    final hasWeightConflict =
        peso != null && weight != null && (peso - weight).abs() > 0.01;

    final resolvedWeight = hasWeightConflict ? null : peso ?? weight;

    final createdAt = _dateFrom(map['createdAt']) ?? _dateFrom(map['criadoEm']);

    return FitnessProfileModel(
      weightKg: resolvedWeight,
      heightCm: _legacyHeightCm(map['altura']),
      objective: _stringFrom(map['objetivo']) ?? _stringFrom(map['objectives']),
      weeklyFrequency: _frequencyFrom(map['freq_semanal']),
      updatedAt:
          _dateFrom(map['updatedAt']) ??
          _dateFrom(map['lastUpdate']) ??
          createdAt,
      legacyWeightConflict: hasWeightConflict,
    );
  }

  /// Serializa somente o formato canônico.
  Map<String, dynamic> toMap() {
    return {
      'weightKg': weightKg,
      'heightCm': heightCm,
      'objective': objective,
      'weeklyFrequency': weeklyFrequency,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static double? _numberFrom(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is! String) {
      return null;
    }

    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty || normalized == '--') {
      return null;
    }

    return double.tryParse(normalized);
  }

  static double? _legacyHeightCm(dynamic value) {
    final parsed = _numberFrom(value);

    if (parsed == null || parsed <= 0) {
      return null;
    }

    // Alguns registros históricos podem ter altura em metros,
    // por exemplo 1.75, enquanto outros usam centímetros.
    //
    // Valores plausíveis <= 3 são tratados como metros.
    if (parsed <= 3) {
      return parsed * 100;
    }

    return parsed;
  }

  static int? _frequencyFrom(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty || normalized == '--') {
      return null;
    }

    final match = RegExp(r'\d+').firstMatch(normalized);

    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0)!);
  }

  static String? _stringFrom(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty || normalized == '--') {
      return null;
    }

    return normalized;
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    return null;
  }
}

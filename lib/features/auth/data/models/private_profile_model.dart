import 'package:cloud_firestore/cloud_firestore.dart';

/// Dados pessoais privados do usuário.
///
/// Caminho canônico:
/// users/{uid}/profile/private
class PrivateProfileModel {
  final DateTime? birthDate;
  final String? gender;
  final DateTime? updatedAt;

  const PrivateProfileModel({this.birthDate, this.gender, this.updatedAt});

  /// Lê o formato canônico User v2.
  factory PrivateProfileModel.fromMap(Map<String, dynamic> map) {
    return PrivateProfileModel(
      birthDate: _dateFrom(map['birthDate']),
      gender: _stringFrom(map['gender']),
      updatedAt: _dateFrom(map['updatedAt']),
    );
  }

  /// Compatibilidade temporária com dados que ainda estão
  /// diretamente em users/{uid}.
  factory PrivateProfileModel.fromLegacyUserMap(Map<String, dynamic> map) {
    final createdAt = _dateFrom(map['createdAt']) ?? _dateFrom(map['criadoEm']);

    return PrivateProfileModel(
      birthDate:
          _dateFrom(map['birthDate']) ?? _dateFrom(map['dataNascimento']),
      gender: _stringFrom(map['gender']),
      updatedAt:
          _dateFrom(map['updatedAt']) ??
          _dateFrom(map['lastUpdate']) ??
          createdAt,
    );
  }

  /// Escreve somente o formato canônico.
  Map<String, dynamic> toMap() {
    return {
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
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

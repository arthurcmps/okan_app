class PhysicalAssessment {
  const PhysicalAssessment({
    required this.id,
    required this.date,
    required this.values,
  });

  final String id;
  final DateTime date;
  final Map<String, dynamic> values;

  dynamic operator [](String key) => values[key];

  double? numberValue(String key) {
    final value = values[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }
}

double? calculateBodyMassIndex({
  required double? weight,
  required double? height,
}) {
  if (weight == null || height == null || weight <= 0 || height <= 0) {
    return null;
  }

  final heightInMeters = height > 3 ? height / 100 : height;
  final bmi = weight / (heightInMeters * heightInMeters);
  return double.parse(bmi.toStringAsFixed(2));
}

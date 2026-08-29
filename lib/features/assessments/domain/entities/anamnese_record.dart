class AnamneseRecord {
  const AnamneseRecord({required this.values});

  final Map<String, dynamic> values;

  factory AnamneseRecord.empty() {
    return const AnamneseRecord(values: <String, dynamic>{});
  }
}

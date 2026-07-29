class WorkoutExercise {
  String id;
  String nome;
  String series;
  String repeticoes;
  bool concluido;
  String carga;
  bool solicitarAlteracao;
  String? videoUrl;
  String? observacao;

  WorkoutExercise({
    required this.id,
    required this.nome,
    required this.series,
    required this.repeticoes,
    this.concluido = false,
    this.carga = '',
    this.solicitarAlteracao = false,
    this.videoUrl,
    this.observacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'series': series,
      'repeticoes': repeticoes,
      'concluido': concluido,
      'carga': carga,
      'solicitarAlteracao': solicitarAlteracao,
      'videoUrl': videoUrl,
      'observacao': observacao ?? '',
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      series: map['series'] ?? '',
      repeticoes: map['repeticoes'] ?? '',
      concluido: map['concluido'] ?? false,
      carga: map['carga'] ?? '',
      solicitarAlteracao: map['solicitarAlteracao'] ?? false,
      videoUrl: map['videoUrl'],
      observacao: map['observacao']?.toString(),
    );
  }
}
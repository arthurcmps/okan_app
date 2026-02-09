class WorkoutExercise {
  String id;
  String nome;
  String series;
  String repeticoes;
  String carga; 
  bool concluido;

  WorkoutExercise({
    required this.id,
    required this.nome,
    required this.series,
    required this.repeticoes,
    this.carga = '',
    this.concluido = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'series': series,
      'repeticoes': repeticoes,
      'carga': carga,
      'concluido': concluido,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      series: map['series'] ?? '',
      repeticoes: map['repeticoes'] ?? '',
      carga: map['carga'] ?? '',
      concluido: map['concluido'] ?? false,
    );
  }
}
class WorkoutExercise {
  String id;
  String nome;
  String series;
  String repeticoes;
  String carga;
  bool concluido;
  bool solicitarAlteracao; // <--- NOVO CAMPO AQUI

  WorkoutExercise({
    required this.id,
    required this.nome,
    required this.series,
    required this.repeticoes,
    this.carga = '',
    this.concluido = false,
    this.solicitarAlteracao = false, // <--- INICIA COMO FALSO
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'series': series,
      'repeticoes': repeticoes,
      'carga': carga,
      'concluido': concluido,
      'solicitarAlteracao': solicitarAlteracao, // <--- SALVA NO BANCO
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
      solicitarAlteracao: map['solicitarAlteracao'] ?? false, // <--- LÊ DO BANCO
    );
  }
}
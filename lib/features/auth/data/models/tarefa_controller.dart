class Tarefa {
  String id;
  String titulo;
  bool concluida;

  Tarefa({required this.id, required this.titulo, this.concluida = false});

  factory Tarefa.fromMap(String id, Map<String, dynamic> map) {
    return Tarefa(
      id: id,
      titulo: map['titulo'] ?? '',
      concluida: map['concluida'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'concluida': concluida,
    };
  }
}
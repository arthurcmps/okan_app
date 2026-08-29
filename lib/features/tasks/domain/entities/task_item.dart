class Tarefa {
  Tarefa({
    required this.id,
    required this.titulo,
    required this.concluida,
    required this.userId,
    required this.dataCriacao,
    this.dataConclusao,
  });

  String id;
  String titulo;
  bool concluida;
  String userId;
  DateTime dataCriacao;
  DateTime? dataConclusao;
}

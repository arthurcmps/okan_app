import 'package:cloud_firestore/cloud_firestore.dart';

class Tarefa {
  String id;
  String titulo;
  bool concluida;
  String userId;
  DateTime dataCriacao;
  DateTime? dataConclusao;

  Tarefa({
    required this.id,
    required this.titulo,
    required this.concluida,
    required this.userId,
    required this.dataCriacao,
    this.dataConclusao,
  });

  factory Tarefa.fromMap(String id, Map<String, dynamic> map) {
    // Tenta pegar a data nova. Se não tiver, tenta a antiga ('data'). Se não, usa Agora.
    Timestamp? timestampCriacao = map['dataCriacao'] as Timestamp? ?? map['data'] as Timestamp?;
    
    // Tenta pegar dataConclusao
    Timestamp? timestampConclusao = map['dataConclusao'] as Timestamp?;

    return Tarefa(
      id: id,
      titulo: map['titulo'] ?? 'Sem Título',
      concluida: map['concluida'] ?? false,
      userId: map['userId'] ?? '',
      dataCriacao: timestampCriacao?.toDate() ?? DateTime.now(),
      dataConclusao: timestampConclusao?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'concluida': concluida,
      'userId': userId,
      'dataCriacao': Timestamp.fromDate(dataCriacao),
      'dataConclusao': dataConclusao != null ? Timestamp.fromDate(dataConclusao!) : null,
      // Não salvamos mais 'data', usamos o padrão novo 'dataCriacao'
    };
  }
}
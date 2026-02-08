import 'package:cloud_firestore/cloud_firestore.dart';

class Tarefa {
  String id;
  String titulo;
  bool concluida;
  DateTime dataCriacao;
  DateTime? dataConclusao; // Pode ser nulo (ainda não acabou)

  Tarefa({
    required this.id,
    required this.titulo,
    this.concluida = false,
    required this.dataCriacao,
    this.dataConclusao,
  });

  factory Tarefa.fromMap(String id, Map<String, dynamic> map) {
    return Tarefa(
      id: id,
      titulo: map['titulo'] ?? '',
      concluida: map['concluida'] ?? false,
      // Converte Timestamp do Firebase para DateTime do Flutter
      dataCriacao: (map['dataCriacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataConclusao: (map['dataConclusao'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'concluida': concluida,
      'dataCriacao': Timestamp.fromDate(dataCriacao),
      'dataConclusao': dataConclusao != null ? Timestamp.fromDate(dataConclusao!) : null,
    };
  }
}
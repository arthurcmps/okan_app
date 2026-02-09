import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_plans_model.dart'; // Importe o modelo de exercícios

class WorkoutHistory {
  String id;
  String studentId;
  String diaDaSemana; // Ex: "segunda"
  DateTime dataRealizacao;
  List<WorkoutExercise> exercicios;

  WorkoutHistory({
    required this.id,
    required this.studentId,
    required this.diaDaSemana,
    required this.dataRealizacao,
    required this.exercicios,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'diaDaSemana': diaDaSemana,
      'dataRealizacao': Timestamp.fromDate(dataRealizacao),
      'exercicios': exercicios.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkoutHistory.fromMap(String id, Map<String, dynamic> map) {
    return WorkoutHistory(
      id: id,
      studentId: map['studentId'] ?? '',
      diaDaSemana: map['diaDaSemana'] ?? '',
      dataRealizacao: (map['dataRealizacao'] as Timestamp).toDate(),
      exercicios: (map['exercicios'] as List<dynamic>)
          .map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
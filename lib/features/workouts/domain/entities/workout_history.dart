import 'workout_exercise.dart';

class WorkoutHistory {
  WorkoutHistory({
    required this.id,
    required this.studentId,
    required this.diaDaSemana,
    required this.dataRealizacao,
    required this.exercicios,
    this.feedback = '',
  });

  final String id;
  final String studentId;
  final String diaDaSemana;
  final DateTime dataRealizacao;
  final List<WorkoutExercise> exercicios;
  final String feedback;
}

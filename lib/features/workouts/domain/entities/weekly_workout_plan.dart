import 'workout_exercise.dart';

class WeeklyWorkoutPlan {
  const WeeklyWorkoutPlan({
    required this.exercisesByDay,
    required this.feedbackByDay,
    this.validade,
    this.avisadoVencimento = false,
  });

  final Map<String, List<WorkoutExercise>> exercisesByDay;
  final Map<String, String> feedbackByDay;
  final DateTime? validade;
  final bool avisadoVencimento;

  List<WorkoutExercise> exercisesFor(String dayKey) {
    return exercisesByDay[dayKey] ?? <WorkoutExercise>[];
  }

  String feedbackFor(String dayKey) {
    return feedbackByDay[dayKey] ?? '';
  }
}

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.nome,
    required this.exercicios,
    this.createdAt,
  });

  final String id;
  final String nome;
  final List<WorkoutExercise> exercicios;
  final DateTime? createdAt;
}

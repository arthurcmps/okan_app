import 'workout_exercise.dart';

class WorkoutModel {
  WorkoutModel({
    required this.id,
    required this.nome,
    required this.grupoMuscular,
    required this.exercicios,
  });

  final String id;
  final String nome;
  final String grupoMuscular;
  final List<WorkoutExercise> exercicios;
}

class WorkoutCatalogExercise {
  WorkoutCatalogExercise({
    required this.nome,
    required this.grupo,
    required this.videoUrl,
  });

  final String nome;
  final String grupo;
  final String videoUrl;
}

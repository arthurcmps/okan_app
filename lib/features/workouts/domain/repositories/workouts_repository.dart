import '../entities/workout_exercise.dart';
import '../entities/workout_history.dart';
import '../entities/workout_model.dart';

abstract class WorkoutsRepository {
  Stream<List<WorkoutModel>> watchWorkoutModels();

  Stream<List<WorkoutCatalogExercise>> watchExerciseCatalog();

  Future<void> saveWorkoutModel({
    String? workoutId,
    required String nome,
    required String grupoMuscular,
    required List<WorkoutExercise> exercicios,
    required String? personalId,
  });

  Future<void> deleteWorkoutModel(String workoutId);

  Future<List<WorkoutExercise>> loadWorkoutDay({
    required String studentId,
    required String dayKey,
  });

  Future<void> completeWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
    required String feedback,
  });

  Stream<List<WorkoutHistory>> watchWorkoutHistory(String studentId);
}

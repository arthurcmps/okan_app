import '../entities/weekly_workout_plan.dart';
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

  Stream<WeeklyWorkoutPlan> watchWeeklyPlan(String studentId);

  Future<void> saveWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
  });

  Future<void> appendWorkoutDays({
    required String studentId,
    required Map<String, List<WorkoutExercise>> exercisesByDay,
  });

  Future<void> saveWorkoutFeedback({
    required String studentId,
    required String dayKey,
    required String feedback,
  });

  Future<void> clearWorkoutFeedback({
    required String studentId,
    required String dayKey,
  });

  Future<void> setWorkoutValidity({
    required String studentId,
    required DateTime validade,
  });

  Future<void> markExpiryWarningSent(String studentId);

  Future<bool> isTrainingProfessional(String userId);

  Future<String?> findStudentProfessionalId(String studentId);

  Future<void> notifyUser({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String actionId,
  });

  Stream<List<WorkoutTemplate>> watchWorkoutTemplates(String personalId);

  Future<void> saveWorkoutTemplate({
    required String personalId,
    required String nome,
    required List<WorkoutExercise> exercises,
  });

  Future<void> deleteWorkoutTemplate(String templateId);

  Future<void> completeWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
    required String feedback,
    bool clearPlanFeedback = false,
  });

  Stream<List<WorkoutHistory>> watchWorkoutHistory(String studentId);
}

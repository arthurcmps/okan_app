import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';

class FirebaseWorkoutsRepository implements WorkoutsRepository {
  FirebaseWorkoutsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<WorkoutModel>> watchWorkoutModels() {
    return _firestore
        .collection('workouts')
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final exercises = (data['exercicios'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => WorkoutExercise.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false);

            return WorkoutModel(
              id: doc.id,
              nome: data['nome']?.toString() ?? 'Sem Nome',
              grupoMuscular: data['grupoMuscular']?.toString() ?? 'Geral',
              exercicios: exercises,
            );
          }).toList(growable: false),
        );
  }

  @override
  Stream<List<WorkoutCatalogExercise>> watchExerciseCatalog() {
    return _firestore
        .collection('exercises')
        .orderBy('nome')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return WorkoutCatalogExercise(
              nome: data['nome']?.toString() ?? '',
              grupo: data['grupo']?.toString() ?? '',
              videoUrl: data['videoUrl']?.toString() ?? '',
            );
          }).toList(growable: false),
        );
  }

  @override
  Future<void> saveWorkoutModel({
    String? workoutId,
    required String nome,
    required String grupoMuscular,
    required List<WorkoutExercise> exercicios,
    required String? personalId,
  }) async {
    final payload = <String, dynamic>{
      'nome': nome.trim(),
      'grupoMuscular': grupoMuscular.trim(),
      'exercicios': exercicios.map((exercise) => exercise.toMap()).toList(),
      'atualizadoEm': FieldValue.serverTimestamp(),
      'personalId': personalId,
    };

    if (workoutId == null) {
      payload['criadoEm'] = FieldValue.serverTimestamp();
      await _firestore.collection('workouts').add(payload);
      return;
    }

    await _firestore.collection('workouts').doc(workoutId).update(payload);
  }

  @override
  Future<void> deleteWorkoutModel(String workoutId) {
    return _firestore.collection('workouts').doc(workoutId).delete();
  }

  @override
  Future<List<WorkoutExercise>> loadWorkoutDay({
    required String studentId,
    required String dayKey,
  }) async {
    final snapshot = await _firestore
        .collection('workout_plans')
        .doc(studentId)
        .get();

    if (!snapshot.exists) return <WorkoutExercise>[];

    final raw = snapshot.data()?[dayKey] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => WorkoutExercise.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  @override
  Future<void> completeWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
    required String feedback,
  }) async {
    await _firestore.collection('workout_history').add({
      'studentId': studentId,
      'diaDaSemana': dayKey,
      'dataRealizacao': FieldValue.serverTimestamp(),
      'exercicios': exercises.map((exercise) => exercise.toMap()).toList(),
      'feedback': feedback,
    });

    final planRef = _firestore.collection('workout_plans').doc(studentId);
    final planSnapshot = await planRef.get();
    if (!planSnapshot.exists) return;

    final raw = planSnapshot.data()?[dayKey] as List<dynamic>? ?? const [];
    final resetExercises = raw.map((item) {
      if (item is! Map) return item;
      final exercise = Map<String, dynamic>.from(item);
      exercise['concluido'] = false;
      return exercise;
    }).toList();

    await planRef.update({dayKey: resetExercises});
  }

  @override
  Stream<List<WorkoutHistory>> watchWorkoutHistory(String studentId) {
    return _firestore
        .collection('workout_history')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final history = snapshot.docs.map((doc) {
            final data = doc.data();
            final exercises = (data['exercicios'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => WorkoutExercise.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false);

            return WorkoutHistory(
              id: doc.id,
              studentId: data['studentId']?.toString() ?? '',
              diaDaSemana: data['diaDaSemana']?.toString() ?? '',
              dataRealizacao: _dateFrom(data['dataRealizacao']),
              exercicios: exercises,
              feedback: data['feedback']?.toString() ?? '',
            );
          }).toList();

          history.sort(
            (a, b) => b.dataRealizacao.compareTo(a.dataRealizacao),
          );
          return history;
        });
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

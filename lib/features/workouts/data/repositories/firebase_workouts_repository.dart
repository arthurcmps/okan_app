import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/weekly_workout_plan.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';

class FirebaseWorkoutsRepository implements WorkoutsRepository {
  FirebaseWorkoutsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _weekDays = <String>[
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
  ];

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
            final exercises = _exercisesFrom(data['exercicios']);

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
    return _exercisesFrom(snapshot.data()?[dayKey]);
  }

  @override
  Stream<WeeklyWorkoutPlan> watchWeeklyPlan(String studentId) {
    return _firestore
        .collection('workout_plans')
        .doc(studentId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? <String, dynamic>{};
          final exercisesByDay = <String, List<WorkoutExercise>>{};
          final feedbackByDay = <String, String>{};

          for (final day in _weekDays) {
            exercisesByDay[day] = _exercisesFrom(data[day]);
            final feedback = data['feedback_$day']?.toString().trim() ?? '';
            if (feedback.isNotEmpty) {
              feedbackByDay[day] = feedback;
            }
          }

          return WeeklyWorkoutPlan(
            exercisesByDay: exercisesByDay,
            feedbackByDay: feedbackByDay,
            validade: _nullableDateFrom(data['validade']),
            avisadoVencimento: data['avisadoVencimento'] == true,
          );
        });
  }

  @override
  Future<void> saveWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
  }) {
    return _firestore.collection('workout_plans').doc(studentId).set(
      {dayKey: exercises.map((exercise) => exercise.toMap()).toList()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveWorkoutFeedback({
    required String studentId,
    required String dayKey,
    required String feedback,
  }) {
    return _firestore.collection('workout_plans').doc(studentId).set(
      {'feedback_$dayKey': feedback.trim()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> clearWorkoutFeedback({
    required String studentId,
    required String dayKey,
  }) {
    return _firestore.collection('workout_plans').doc(studentId).set(
      {'feedback_$dayKey': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> setWorkoutValidity({
    required String studentId,
    required DateTime validade,
  }) {
    return _firestore.collection('workout_plans').doc(studentId).set(
      {
        'validade': Timestamp.fromDate(validade),
        'avisadoVencimento': false,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markExpiryWarningSent(String studentId) {
    return _firestore.collection('workout_plans').doc(studentId).set(
      {'avisadoVencimento': true},
      SetOptions(merge: true),
    );
  }

  @override
  Future<bool> isTrainingProfessional(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) return false;

    final profile = UserModel.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      snapshot.id,
    );
    return profile.isTrainingProfessional;
  }

  @override
  Future<String?> findStudentProfessionalId(String studentId) async {
    final snapshot = await _firestore.collection('users').doc(studentId).get();
    if (!snapshot.exists) return null;

    final profile = UserModel.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      snapshot.id,
    );
    return profile.professorId;
  }

  @override
  Future<void> notifyUser({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String actionId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'type': type,
          'title': title,
          'body': body,
          'actionId': actionId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  @override
  Stream<List<WorkoutTemplate>> watchWorkoutTemplates(String personalId) {
    return _firestore
        .collection('workout_templates')
        .where('personalId', isEqualTo: personalId)
        .snapshots()
        .map((snapshot) {
          final templates = snapshot.docs.map((doc) {
            final data = doc.data();
            return WorkoutTemplate(
              id: doc.id,
              nome: data['nome']?.toString() ?? 'Sem nome',
              exercicios: _exercisesFrom(data['exercicios']),
              createdAt: _nullableDateFrom(data['timestamp']),
            );
          }).toList();

          templates.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          return templates;
        });
  }

  @override
  Future<void> saveWorkoutTemplate({
    required String personalId,
    required String nome,
    required List<WorkoutExercise> exercises,
  }) {
    return _firestore.collection('workout_templates').add({
      'personalId': personalId,
      'nome': nome.trim(),
      'exercicios': exercises.map((exercise) => exercise.toMap()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteWorkoutTemplate(String templateId) {
    return _firestore.collection('workout_templates').doc(templateId).delete();
  }

  @override
  Future<void> completeWorkoutDay({
    required String studentId,
    required String dayKey,
    required List<WorkoutExercise> exercises,
    required String feedback,
    bool clearPlanFeedback = false,
  }) async {
    await _firestore.collection('workout_history').add({
      'studentId': studentId,
      'diaDaSemana': dayKey,
      'dataRealizacao': FieldValue.serverTimestamp(),
      'exercicios': exercises.map((exercise) => exercise.toMap()).toList(),
      'feedback': feedback,
    });

    final resetExercises = exercises.map((exercise) {
      final copy = WorkoutExercise.fromMap(exercise.toMap());
      copy.concluido = false;
      return copy;
    }).toList(growable: false);

    final payload = <String, dynamic>{
      dayKey: resetExercises.map((exercise) => exercise.toMap()).toList(),
    };
    if (clearPlanFeedback) {
      payload['feedback_$dayKey'] = FieldValue.delete();
    }

    await _firestore.collection('workout_plans').doc(studentId).set(
      payload,
      SetOptions(merge: true),
    );
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
            return WorkoutHistory(
              id: doc.id,
              studentId: data['studentId']?.toString() ?? '',
              diaDaSemana: data['diaDaSemana']?.toString() ?? '',
              dataRealizacao: _dateFrom(data['dataRealizacao']),
              exercicios: _exercisesFrom(data['exercicios']),
              feedback: data['feedback']?.toString() ?? '',
            );
          }).toList();

          history.sort(
            (a, b) => b.dataRealizacao.compareTo(a.dataRealizacao),
          );
          return history;
        });
  }

  List<WorkoutExercise> _exercisesFrom(dynamic value) {
    final raw = value as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => WorkoutExercise.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  DateTime _dateFrom(dynamic value) {
    return _nullableDateFrom(value) ?? DateTime.now();
  }

  DateTime? _nullableDateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

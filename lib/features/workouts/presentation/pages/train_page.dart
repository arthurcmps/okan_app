import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/repositories/workouts_repository.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({
    super.key,
    required this.workoutId,
    this.repository,
  });

  final String workoutId;
  final WorkoutsRepository? repository;

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  final Map<int, bool> _concluidos = {};
  final Map<int, String> _cargas = {};

  late final WorkoutsRepository _repository;
  late final Future<List<WorkoutExercise>> _exercisesFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkoutsRepository();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _exercisesFuture = userId == null
        ? Future.value(<WorkoutExercise>[])
        : _repository.loadWorkoutDay(
            studentId: userId,
            dayKey: widget.workoutId,
          );
  }

  void _pedirFeedbackEFinalizar(List<WorkoutExercise> exercises) {
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Treino Concluído! 🎉',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deixe um feedback para o seu personal (Opcional):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Senti facilidade, ou dor no ombro...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _finalizarTreino(exercises, feedbackCtrl.text.trim());
            },
            child: const Text(
              'Salvar Histórico',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarTreino(
    List<WorkoutExercise> originalExercises,
    String feedback,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final completedExercises = <WorkoutExercise>[];
    for (var index = 0; index < originalExercises.length; index++) {
      final original = originalExercises[index];
      completedExercises.add(
        WorkoutExercise(
          id: original.id.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : original.id,
          nome: original.nome,
          series: original.series,
          repeticoes: original.repeticoes,
          concluido: _concluidos[index] == true,
          carga: _cargas[index] ?? original.carga,
          solicitarAlteracao: original.solicitarAlteracao,
          videoUrl: original.videoUrl,
          observacao: original.observacao,
        ),
      );
    }

    try {
      await _repository.completeWorkoutDay(
        studentId: userId,
        dayKey: widget.workoutId,
        exercises: completedExercises,
        feedback: feedback,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Treino finalizado e salvo no histórico!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Treino - ${widget.workoutId.toUpperCase()}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<WorkoutExercise>>(
        future: _exercisesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final exercises = snapshot.data ?? const <WorkoutExercise>[];
          if (exercises.isEmpty) {
            return const Center(
              child: Text(
                'Você não tem exercícios para hoje.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _concluidos[index] ?? false,
                                  activeColor: AppColors.secondary,
                                  checkColor: Colors.black,
                                  onChanged: (value) => setState(
                                    () => _concluidos[index] = value ?? false,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    exercise.nome,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${exercise.series}x ${exercise.repeticoes}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Carga',
                                      hintText: exercise.carga,
                                      filled: true,
                                      fillColor: Colors.black26,
                                      suffixText: 'kg',
                                      suffixStyle: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSub,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (value) => _cargas[index] = value,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                color: AppColors.surface,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.black),
                  label: const Text(
                    'FINALIZAR TREINO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () => _pedirFeedbackEFinalizar(exercises),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

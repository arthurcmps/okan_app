import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/evolution_charts_page.dart';
import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/workouts_repository.dart';

class WorkoutHistoryPage extends StatelessWidget {
  WorkoutHistoryPage({
    super.key,
    required this.studentId,
    required this.studentName,
    WorkoutsRepository? repository,
  }) : _repository = repository ?? FirebaseWorkoutsRepository();

  final String studentId;
  final String studentName;
  final WorkoutsRepository _repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Histórico de Treinos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvolutionChartsPage(
                      studentId: studentId,
                      studentName: studentName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.insights, color: AppColors.primary),
              label: const Text(
                'Gráficos',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<WorkoutHistory>>(
        stream: _repository.watchWorkoutHistory(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final historyList = snapshot.data!;
          if (historyList.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum treino finalizado ainda.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];
              final exercises = history.exercicios;
              final dateStr = DateFormat("dd/MM/yyyy 'às' HH:mm")
                  .format(history.dataRealizacao);
              final dayName = history.diaDaSemana.toUpperCase();
              final completedCount = exercises
                  .where((exercise) => exercise.concluido)
                  .length;

              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: AppColors.primary,
                    collapsedIconColor: Colors.white54,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.success.withOpacity(0.2),
                      child: const Icon(Icons.check, color: AppColors.success),
                    ),
                    title: Text(
                      '$dayName - $dateStr',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '$completedCount/${exercises.length} exercícios concluídos',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    children: [
                      ...exercises.map(_buildExerciseRow),
                      if (history.feedback.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Feedback do Aluno:',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      history.feedback,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExerciseRow(WorkoutExercise exercise) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        exercise.concluido ? Icons.check_circle : Icons.cancel,
        color: exercise.concluido
            ? AppColors.success
            : Colors.redAccent.withOpacity(0.5),
        size: 18,
      ),
      title: Text(
        exercise.nome,
        style: TextStyle(
          color: exercise.concluido ? Colors.white : Colors.white54,
          decoration: exercise.concluido ? null : TextDecoration.lineThrough,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: (exercise.observacao ?? '').trim().isNotEmpty
          ? Text(
              'Obs: ${exercise.observacao}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          : null,
      trailing: Text(
        exercise.carga.isEmpty ? '' : '${exercise.carga}kg',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';
import 'create_workout_page.dart';

class ManageWorkoutsPage extends StatelessWidget {
  ManageWorkoutsPage({
    super.key,
    WorkoutsRepository? repository,
  }) : _repository = repository ?? FirebaseWorkoutsRepository();

  final WorkoutsRepository _repository;

  void _deletarTreino(
    BuildContext context,
    String treinoId,
    String nomeTreino,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Treino?'),
        content: Text("Tem certeza que deseja apagar '$nomeTreino'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _repository.deleteWorkoutModel(treinoId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Treino excluído.')),
              );
            },
            child: Text(
              'Excluir',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _editarTreino(BuildContext context, WorkoutModel workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWorkoutPage(
          treinoId: workout.id,
          treinoDados: {
            'nome': workout.nome,
            'grupoMuscular': workout.grupoMuscular,
            'exercicios': workout.exercicios
                .map((exercise) => exercise.toMap())
                .toList(),
          },
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Modelos')),
      body: StreamBuilder<List<WorkoutModel>>(
        stream: _repository.watchWorkoutModels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          final workouts = snapshot.data ?? const <WorkoutModel>[];
          if (workouts.isEmpty) {
            return Center(
              key: const ValueKey('manage-workouts-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum modelo criado.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quando você criar um modelo de treino, ele aparecerá aqui.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                key: const ValueKey('manage-workouts-list'),
                padding: const EdgeInsets.all(16),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  final exerciseCount = workout.exercicios.length;
                  final exerciseLabel = exerciseCount == 1
                      ? '1 exercício'
                      : '$exerciseCount exercícios';

                  return Card(
                    key: ValueKey('manage-workout-card-${workout.id}'),
                    color: colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withOpacity(0.14),
                        foregroundColor: colorScheme.primary,
                        child: const Icon(Icons.fitness_center),
                      ),
                      title: Text(
                        workout.nome,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '${workout.grupoMuscular} • $exerciseLabel',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey(
                              'manage-workout-edit-${workout.id}',
                            ),
                            tooltip: 'Editar treino',
                            icon: Icon(Icons.edit, color: colorScheme.primary),
                            onPressed: () => _editarTreino(context, workout),
                          ),
                          IconButton(
                            key: ValueKey(
                              'manage-workout-delete-${workout.id}',
                            ),
                            tooltip: 'Excluir treino',
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                            onPressed: () => _deletarTreino(
                              context,
                              workout.id,
                              workout.nome,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/widgets/okan_async_state.dart';
import '../../domain/entities/workout_model.dart';

class WorkoutModelList extends StatelessWidget {
  final List<WorkoutModel> workouts;
  final Set<String> deletingWorkoutIds;
  final ValueChanged<WorkoutModel> onEdit;
  final ValueChanged<WorkoutModel> onDelete;

  const WorkoutModelList({
    super.key,
    required this.workouts,
    required this.deletingWorkoutIds,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const OkanMessageState(
        key: ValueKey('workout-models-empty'),
        icon: Icons.fitness_center_outlined,
        title: 'Nenhum modelo criado',
        description:
            'Crie um treino e salve-o como modelo para reutilizar depois.',
      );
    }

    return ListView.separated(
      key: const ValueKey('workout-models-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      itemCount: workouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return WorkoutModelCard(
          workout: workout,
          isDeleting: deletingWorkoutIds.contains(workout.id),
          onEdit: () => onEdit(workout),
          onDelete: () => onDelete(workout),
        );
      },
    );
  }
}

class WorkoutModelCard extends StatelessWidget {
  final WorkoutModel workout;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WorkoutModelCard({
    super.key,
    required this.workout,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exerciseCount = workout.exercicios.length;
    final exerciseLabel = exerciseCount == 1
        ? '1 exercício'
        : '$exerciseCount exercícios';
    final muscleGroup = workout.grupoMuscular.trim().isEmpty
        ? 'Grupo muscular não informado'
        : workout.grupoMuscular.trim();

    return Card(
      key: ValueKey('workout-model-${workout.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    backgroundColor: colors.secondary.withOpacity(0.14),
                    foregroundColor: colors.secondary,
                    child: const Icon(Icons.fitness_center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.nome,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$muscleGroup • $exerciseLabel',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: 'Editar ${workout.nome}',
                  child: OutlinedButton.icon(
                    key: ValueKey('edit-workout-${workout.id}'),
                    onPressed: isDeleting ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                Tooltip(
                  message: 'Excluir ${workout.nome}',
                  child: TextButton.icon(
                    key: ValueKey('delete-workout-${workout.id}'),
                    onPressed: isDeleting ? null : onDelete,
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    icon: isDeleting
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.error,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(isDeleting ? 'Excluindo...' : 'Excluir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

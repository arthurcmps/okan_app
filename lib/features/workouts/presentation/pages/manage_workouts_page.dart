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
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Modelos')),
      body: StreamBuilder<List<WorkoutModel>>(
        stream: _repository.watchWorkoutModels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.data ?? const <WorkoutModel>[];
          if (workouts.isEmpty) {
            return const Center(child: Text('Nenhum modelo criado.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: const Icon(Icons.fitness_center, color: Colors.teal),
                  ),
                  title: Text(
                    workout.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${workout.grupoMuscular} • ${workout.exercicios.length} exercícios',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editarTreino(context, workout),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
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
          );
        },
      ),
    );
  }
}

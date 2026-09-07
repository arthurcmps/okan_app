import 'package:flutter/material.dart';

import '../../../../core/widgets/okan_async_state.dart';
import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';
import 'create_workout_page.dart';

class ManageWorkoutsPage extends StatefulWidget {
  ManageWorkoutsPage({
    super.key,
    WorkoutsRepository? repository,
  }) : _repository = repository ?? FirebaseWorkoutsRepository();

  final WorkoutsRepository _repository;

  @override
  State<ManageWorkoutsPage> createState() => _ManageWorkoutsPageState();
}

class _ManageWorkoutsPageState extends State<ManageWorkoutsPage> {
  late Stream<List<WorkoutModel>> _workoutsStream;
  final Set<String> _deletingWorkoutIds = <String>{};

  @override
  void initState() {
    super.initState();
    _workoutsStream = widget._repository.watchWorkoutModels();
  }

  void _retryLoading() {
    setState(() {
      _workoutsStream = widget._repository.watchWorkoutModels();
    });
  }

  Future<void> _deletarTreino(
    String treinoId,
    String nomeTreino,
  ) async {
    if (_deletingWorkoutIds.contains(treinoId)) return;

    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingWorkoutIds.add(treinoId));

    try {
      await widget._repository.deleteWorkoutModel(treinoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino excluído.')),
      );
    } catch (error) {
      debugPrint(
        'ManageWorkoutsPage/deleteWorkoutModel: ${error.runtimeType}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível excluir o treino. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingWorkoutIds.remove(treinoId));
      }
    }
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
          repository: widget._repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Modelos')),
      body: StreamBuilder<List<WorkoutModel>>(
        stream: _workoutsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const OkanLoadingState(
              label: 'Carregando modelos de treino',
            );
          }

          if (snapshot.hasError) {
            return OkanMessageState(
              key: const ValueKey('workout-models-error'),
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar seus modelos',
              description:
                  'Verifique sua conexão e tente novamente em alguns instantes.',
              actionLabel: 'Tentar novamente',
              onAction: _retryLoading,
              isError: true,
              announce: true,
            );
          }

          final workouts = snapshot.data ?? const <WorkoutModel>[];
          if (workouts.isEmpty) {
            return const OkanMessageState(
              key: ValueKey('workout-models-empty'),
              icon: Icons.fitness_center_outlined,
              title: 'Nenhum modelo criado',
              description:
                  'Crie um treino e salve-o como modelo para reutilizar depois.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              final isDeleting = _deletingWorkoutIds.contains(workout.id);
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
                        key: ValueKey('edit-workout-${workout.id}'),
                        tooltip: 'Editar ${workout.nome}',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: isDeleting
                            ? null
                            : () => _editarTreino(context, workout),
                      ),
                      IconButton(
                        key: ValueKey('delete-workout-${workout.id}'),
                        tooltip: 'Excluir ${workout.nome}',
                        icon: isDeleting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                        onPressed: isDeleting
                            ? null
                            : () => _deletarTreino(
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

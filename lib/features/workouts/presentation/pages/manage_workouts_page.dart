import 'package:flutter/material.dart';

import '../../../../core/widgets/okan_async_state.dart';
import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';
import '../widgets/workout_model_list.dart';
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
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Excluir treino?'),
          content: Text(
            'O modelo “$nomeTreino” será removido permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
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

  void _criarTreino() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWorkoutPage(
          repository: widget._repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Modelos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('create-workout-model'),
        onPressed: _criarTreino,
        icon: const Icon(Icons.add),
        label: const Text('Novo modelo'),
      ),
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
          return WorkoutModelList(
            workouts: workouts,
            deletingWorkoutIds: _deletingWorkoutIds,
            onEdit: (workout) => _editarTreino(context, workout),
            onDelete: (workout) => _deletarTreino(
              workout.id,
              workout.nome,
            ),
          );
        },
      ),
    );
  }
}

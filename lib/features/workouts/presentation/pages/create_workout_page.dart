import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({
    super.key,
    this.treinoId,
    this.treinoDados,
    this.repository,
  });

  final String? treinoId;
  final Map<String, dynamic>? treinoDados;
  final WorkoutsRepository? repository;

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeTreinoController = TextEditingController();
  final _grupoMuscularController = TextEditingController();
  final List<WorkoutExercise> _exerciciosSelecionados = [];

  late final WorkoutsRepository _repository;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkoutsRepository();

    final data = widget.treinoDados;
    if (data == null) return;

    _nomeTreinoController.text = data['nome']?.toString() ?? '';
    _grupoMuscularController.text = data['grupoMuscular']?.toString() ?? '';
    final rawExercises = data['exercicios'] as List<dynamic>? ?? const [];
    _exerciciosSelecionados.addAll(
      rawExercises.whereType<Map>().map(
        (item) => WorkoutExercise.fromMap(Map<String, dynamic>.from(item)),
      ),
    );
  }

  @override
  void dispose() {
    _nomeTreinoController.dispose();
    _grupoMuscularController.dispose();
    super.dispose();
  }

  Future<void> _salvarTreino() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exerciciosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione exercícios!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repository.saveWorkoutModel(
        workoutId: widget.treinoId,
        nome: _nomeTreinoController.text,
        grupoMuscular: _grupoMuscularController.text,
        exercicios: _exerciciosSelecionados,
        personalId: FirebaseAuth.instance.currentUser?.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.treinoId == null ? 'Treino criado!' : 'Treino atualizado!',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _adicionarExercicioModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Selecione da Biblioteca',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<WorkoutCatalogExercise>>(
                    stream: _repository.watchExerciseCatalog(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final exercises = snapshot.data!;
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          return ListTile(
                            title: Text(exercise.nome),
                            subtitle: Text(exercise.grupo),
                            trailing: Icon(
                              Icons.add_circle_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _configurarSeries(exercise);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _configurarSeries(WorkoutCatalogExercise exercise) {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    final obsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configurar ${exercise.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: seriesCtrl,
              decoration: const InputDecoration(labelText: 'Séries'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: repsCtrl,
              decoration: const InputDecoration(labelText: 'Repetições'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(labelText: 'Observação (Opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _exerciciosSelecionados.add(
                  WorkoutExercise(
                    id: '',
                    nome: exercise.nome,
                    videoUrl: exercise.videoUrl,
                    series: seriesCtrl.text,
                    repeticoes: repsCtrl.text,
                    observacao: obsCtrl.text,
                  ),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.treinoId != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Treino' : 'Criar Treino')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeTreinoController,
                decoration: const InputDecoration(labelText: 'Nome do Treino'),
                validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _grupoMuscularController,
                decoration: const InputDecoration(
                  labelText: 'Grupo Muscular (Ex: Costas)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Exercícios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    key: const ValueKey('create-workout-add-exercise'),
                    tooltip: 'Adicionar exercício',
                    icon: Icon(
                      Icons.add_box,
                      size: 30,
                      color: colorScheme.primary,
                    ),
                    onPressed: _adicionarExercicioModal,
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _exerciciosSelecionados.removeAt(oldIndex);
                      _exerciciosSelecionados.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (var i = 0; i < _exerciciosSelecionados.length; i++)
                      ListTile(
                        key: ValueKey('ex_$i${_exerciciosSelecionados[i].nome}'),
                        tileColor: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.14),
                          foregroundColor: colorScheme.primary,
                          child: Text('${i + 1}'),
                        ),
                        title: Text(_exerciciosSelecionados[i].nome),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_exerciciosSelecionados[i].series}x ${_exerciciosSelecionados[i].repeticoes}',
                            ),
                            if ((_exerciciosSelecionados[i].observacao ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Obs: ${_exerciciosSelecionados[i].observacao}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Remover exercício',
                          icon: Icon(Icons.delete, color: colorScheme.error),
                          onPressed: () => setState(
                            () => _exerciciosSelecionados.removeAt(i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('create-workout-save'),
                  onPressed: _isLoading ? null : _salvarTreino,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text(
                    isEditing ? 'ATUALIZAR TREINO' : 'SALVAR TREINO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/domain/entities/workout_exercise.dart';
import '../../data/repositories/firebase_store_repository.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({
    super.key,
    this.repository,
    this.canManageExerciseCatalog = false,
  });

  final StoreRepository? repository;
  final bool canManageExerciseCatalog;

  @override
  State<LibraryAdminPage> createState() => _LibraryAdminPageState();
}

class _LibraryAdminPageState extends State<LibraryAdminPage>
    with SingleTickerProviderStateMixin {
  late final StoreRepository _repository;
  late final TabController _tabController;
  final _nameCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseStoreRepository();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _videoCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  void _exerciseDialog({StoreExercise? exercise}) {
    if (!widget.canManageExerciseCatalog) return;

    _nameCtrl.text = exercise?.name ?? '';
    _groupCtrl.text = exercise?.group ?? '';
    _videoCtrl.text = exercise?.videoUrl ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              exercise == null ? 'Novo Exercício' : 'Editar Exercício',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _input(_nameCtrl, 'Nome do Exercício'),
                  const SizedBox(height: 12),
                  _input(_groupCtrl, 'Grupo Muscular'),
                  const SizedBox(height: 12),
                  _input(_videoCtrl, 'Link do Vídeo (YouTube)'),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      key: const ValueKey('exercise-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (_nameCtrl.text.trim().isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Informe o nome do exercício.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          await _repository.saveExercise(
                            exerciseId: exercise?.id,
                            name: _nameCtrl.text,
                            group: _groupCtrl.text,
                            videoUrl: _videoCtrl.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (error) {
                          debugPrint(
                            'LibraryAdminPage/saveExercise: '
                            '${error.runtimeType}',
                          );
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSaving = false;
                            errorMessage =
                                'Não foi possível salvar o exercício. '
                                'Tente novamente.';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _input(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _confirmDelete({
    required String title,
    required Future<void> Function() action,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir Item?', style: TextStyle(color: Colors.white)),
        content: Text(
          "Tem certeza que deseja apagar '$title'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await action();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Gerenciar Biblioteca'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercícios'),
            Tab(icon: Icon(Icons.library_books), text: 'Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_exercisesTab(), _templatesTab()],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    final isExerciseTab = _tabController.index == 0;
    if (isExerciseTab && !widget.canManageExerciseCatalog) return null;

    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black,
      onPressed: () {
        if (isExerciseTab) {
          _exerciseDialog();
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TemplateBuilderScreen(repository: _repository),
          ),
        );
      },
      icon: Icon(isExerciseTab ? Icons.add : Icons.post_add),
      label: Text(isExerciseTab ? 'Novo exercício' : 'Novo template'),
    );
  }

  Widget _exercisesTab() {
    return StreamBuilder<List<StoreExercise>>(
      stream: _repository.watchExercises(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Não foi possível carregar o catálogo.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final exercises = snapshot.data!;
        return Column(
          children: [
            if (!widget.canManageExerciseCatalog)
              Container(
                key: const ValueKey('exercise-catalog-read-only'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Este é o catálogo global da Okan. Professores podem usá-lo '
                  'nos próprios templates; somente a administração altera os '
                  'exercícios.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            Expanded(
              child: exercises.isEmpty
                  ? Center(
                      child: Text(
                        widget.canManageExerciseCatalog
                            ? 'Nenhum exercício cadastrado.'
                            : 'O catálogo global ainda está vazio.',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return Card(
                          color: AppColors.surface,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.fitness_center),
                            ),
                            title: Text(
                              exercise.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              exercise.group,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: widget.canManageExerciseCatalog
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar ${exercise.name}',
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () => _exerciseDialog(
                                          exercise: exercise,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir ${exercise.name}',
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                        onPressed: () => _confirmDelete(
                                          title: exercise.name,
                                          action: () => _repository
                                              .deleteExercise(exercise.id),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _templatesTab() {
    return StreamBuilder<List<StoreTemplate>>(
      stream: _repository.watchCurrentProfessionalTemplates(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Não foi possível carregar seus templates.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final templates = snapshot.data!;
        if (templates.isEmpty) {
          return const Center(
            child: Text(
              'Você ainda não criou nenhum template.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return Card(
              color: AppColors.surface,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.library_books)),
                title: Text(
                  template.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${template.legacyExercises.length} exercícios guardados',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TemplateBuilderScreen(
                            existingTemplate: template,
                            repository: _repository,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(
                        title: template.name,
                        action: () => _repository.deleteTemplate(template.id),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TemplateBuilderScreen extends StatefulWidget {
  const TemplateBuilderScreen({
    super.key,
    required this.repository,
    this.existingTemplate,
  });

  final StoreRepository repository;
  final StoreTemplate? existingTemplate;

  @override
  State<TemplateBuilderScreen> createState() => _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends State<TemplateBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final List<WorkoutExercise> _exercises = [];
  bool _isSaving = false;

  bool get _editing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    final template = widget.existingTemplate;
    if (template != null) {
      _nameCtrl.text = template.name;
      _exercises.addAll(
        template.legacyExercises.map(WorkoutExercise.fromMap),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _openCatalog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => StreamBuilder<List<StoreExercise>>(
          stream: widget.repository.watchExercises(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Não foi possível carregar o catálogo.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final exercises = snapshot.data ?? const <StoreExercise>[];
            if (exercises.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'O catálogo global ainda está vazio. Cadastre os exercícios '
                    'administrativos antes de criar um template.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }
            return ListView.builder(
              controller: scrollController,
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return ListTile(
                  title: Text(
                    exercise.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _configureExercise(exercise);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _configureExercise(StoreExercise exercise) {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Séries para: ${exercise.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Row(
          children: [
            Expanded(child: TextField(controller: seriesCtrl)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: repsCtrl)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _exercises.add(
                  WorkoutExercise(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nome: exercise.name,
                    series: seriesCtrl.text,
                    repeticoes: repsCtrl.text,
                    videoUrl: exercise.videoUrl,
                  ),
                );
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    ).whenComplete(() {
      seriesCtrl.dispose();
      repsCtrl.dispose();
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_nameCtrl.text.trim().isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome e adicione exercícios.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.repository.saveProfessionalTemplate(
        templateId: widget.existingTemplate?.id,
        name: _nameCtrl.text,
        exercises: _exercises.map((exercise) => exercise.toMap()).toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint(
        'TemplateBuilderScreen/saveProfessionalTemplate: '
        '${error.runtimeType}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar o template. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Editar Template' : 'Criar Novo Template'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Salvar template',
              icon: const Icon(Icons.check_circle),
              onPressed: _save,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Nome do Treino'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openCatalog,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Exercício'),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return Card(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(
                      exercise.nome,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${exercise.series} séries de ${exercise.repeticoes}',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => _exercises.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

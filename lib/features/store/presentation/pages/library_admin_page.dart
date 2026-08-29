import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/domain/entities/workout_exercise.dart';
import '../../data/repositories/firebase_store_repository.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({super.key, this.repository});

  final StoreRepository? repository;

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
    _nameCtrl.text = exercise?.name ?? '';
    _groupCtrl.text = exercise?.group ?? '';
    _videoCtrl.text = exercise?.videoUrl ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              await _repository.saveExercise(
                exerciseId: exercise?.id,
                name: _nameCtrl.text,
                group: _groupCtrl.text,
                videoUrl: _videoCtrl.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_tabController.index == 0) {
            _exerciseDialog();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TemplateBuilderScreen(repository: _repository),
              ),
            );
          }
        },
        child: Icon(
          _tabController.index == 0 ? Icons.add : Icons.post_add,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _exercisesTab() {
    return StreamBuilder<List<StoreExercise>>(
      stream: _repository.watchExercises(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final exercises = snapshot.data!;
        if (exercises.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum exercício cadastrado.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _exerciseDialog(exercise: exercise),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(
                        title: exercise.name,
                        action: () => _repository.deleteExercise(exercise.id),
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

  Widget _templatesTab() {
    return StreamBuilder<List<StoreTemplate>>(
      stream: _repository.watchCurrentProfessionalTemplates(),
      builder: (context, snapshot) {
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
          padding: const EdgeInsets.all(12),
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
            final exercises = snapshot.data ?? const <StoreExercise>[];
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
    if (_nameCtrl.text.trim().isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome e adicione exercícios.')),
      );
      return;
    }
    await widget.repository.saveProfessionalTemplate(
      templateId: widget.existingTemplate?.id,
      name: _nameCtrl.text,
      exercises: _exercises.map((exercise) => exercise.toMap()).toList(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Editar Template' : 'Criar Novo Template'),
        actions: [
          IconButton(icon: const Icon(Icons.check_circle), onPressed: _save),
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

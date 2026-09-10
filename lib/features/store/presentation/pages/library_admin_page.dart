import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/domain/entities/workout_exercise.dart';
import '../../data/repositories/firebase_store_repository.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';
import '../widgets/exercise_catalog_view.dart';

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({
    super.key,
    this.repository,
    this.canManageExerciseCatalog = false,
    this.catalogOnly = false,
  });

  final StoreRepository? repository;
  final bool canManageExerciseCatalog;
  final bool catalogOnly;

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
  List<StoreExercise> _knownExercises = const <StoreExercise>[];

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
    final messenger = ScaffoldMessenger.of(context);

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
                  _input(
                    _nameCtrl,
                    'Nome do Exercício',
                    maxLength: 80,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    _groupCtrl,
                    'Grupo Muscular',
                    maxLength: 40,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    _videoCtrl,
                    'Link do vídeo (opcional)',
                    maxLength: 500,
                    keyboardType: TextInputType.url,
                  ),
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
                        final validationMessage = _exerciseValidationMessage(
                          editingExerciseId: exercise?.id,
                        );
                        if (validationMessage != null) {
                          setDialogState(() {
                            errorMessage = validationMessage;
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
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                exercise == null
                                    ? 'Exercício adicionado ao catálogo.'
                                    : 'Exercício atualizado.',
                              ),
                            ),
                          );
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

  String? _exerciseValidationMessage({String? editingExerciseId}) {
    final name = _nameCtrl.text.trim();
    final group = _groupCtrl.text.trim();
    final videoUrl = _videoCtrl.text.trim();

    if (name.isEmpty) return 'Informe o nome do exercício.';
    if (group.isEmpty) return 'Informe o grupo muscular.';

    final normalizedName = _normalizedExerciseName(name);
    final duplicate = _knownExercises.any(
      (item) =>
          item.id != editingExerciseId &&
          _normalizedExerciseName(item.name) == normalizedName,
    );
    if (duplicate) return 'Já existe um exercício com esse nome.';

    if (videoUrl.isNotEmpty) {
      final uri = Uri.tryParse(videoUrl);
      final hasValidUrl = uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
      if (!hasValidUrl) {
        return 'Informe um link de vídeo válido, começando com http ou https.';
      }
    }

    return null;
  }

  String _normalizedExerciseName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Widget _input(
    TextEditingController controller,
    String label, {
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
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
    required String description,
    required Future<void> Function() action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isDeleting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              'Excluir “$title”?',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    key: const ValueKey('catalog-delete-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isDeleting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                          errorMessage = null;
                        });
                        try {
                          await action();
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Item excluído.')),
                          );
                        } catch (error) {
                          debugPrint(
                            'LibraryAdminPage/delete: ${error.runtimeType}',
                          );
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isDeleting = false;
                            errorMessage =
                                'Não foi possível excluir. Tente novamente.';
                          });
                        }
                      },
                child: isDeleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Excluir'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          widget.catalogOnly
              ? 'Administrar catálogo'
              : 'Gerenciar Biblioteca',
        ),
        bottom: widget.catalogOnly
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.fitness_center), text: 'Exercícios'),
                  Tab(icon: Icon(Icons.library_books), text: 'Templates'),
                ],
              ),
      ),
      body: widget.catalogOnly
          ? _exercisesTab()
          : TabBarView(
              controller: _tabController,
              children: [_exercisesTab(), _templatesTab()],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    final isExerciseTab = widget.catalogOnly || _tabController.index == 0;
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
        _knownExercises = exercises;
        return ExerciseCatalogView(
          exercises: exercises,
          canManage: widget.canManageExerciseCatalog,
          onEdit: (exercise) => _exerciseDialog(exercise: exercise),
          onDelete: (exercise) => _confirmDelete(
            title: exercise.name,
            description:
                'O exercício será removido do catálogo global. Templates e '
                'treinos já salvos manterão suas próprias cópias.',
            action: () => _repository.deleteExercise(exercise.id),
          ),
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
                        description:
                            'O template será removido permanentemente da sua '
                            'biblioteca.',
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

class _ExerciseConfiguration {
  const _ExerciseConfiguration({
    required this.series,
    required this.repetitions,
  });

  final String series;
  final String repetitions;
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

  Future<void> _openCatalog() async {
    final selectedExercise = await showModalBottomSheet<StoreExercise>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
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
                  onTap: () => Navigator.pop(sheetContext, exercise),
                );
              },
            );
          },
        ),
      ),
    );

    if (!mounted || selectedExercise == null) return;
    await _configureExercise(selectedExercise);
  }

  Future<void> _configureExercise(StoreExercise exercise) async {
    var series = '3';
    var repetitions = '12';

    final configuration = await showDialog<_ExerciseConfiguration>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Séries para: ${exercise.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: series,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Séries'),
                onChanged: (value) => series = value,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: repetitions,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Repetições'),
                onChanged: (value) => repetitions = value,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _ExerciseConfiguration(
                series: series.trim(),
                repetitions: repetitions.trim(),
              ),
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (!mounted || configuration == null) return;
    setState(() {
      _exercises.add(
        WorkoutExercise(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nome: exercise.name,
          series: configuration.series,
          repeticoes: configuration.repetitions,
          videoUrl: exercise.videoUrl,
        ),
      );
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

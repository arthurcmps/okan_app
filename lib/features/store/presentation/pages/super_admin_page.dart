import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/domain/entities/workout_exercise.dart';
import '../../data/repositories/firebase_store_repository.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key, this.repository});

  final StoreRepository? repository;

  StoreRepository get _repository => repository ?? FirebaseStoreRepository();

  @override
  Widget build(BuildContext context) {
    final store = _repository;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.redAccent.withOpacity(0.1),
        foregroundColor: Colors.redAccent,
        title: const Text('⚙️ SUPER ADMIN: LOJA'),
      ),
      body: StreamBuilder<List<StoreTemplate>>(
        stream: store.watchSystemTemplates(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum produto na loja do sistema.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final sheetCount = template.sheets.isNotEmpty
                  ? template.sheets.length
                  : template.legacyExercises.isEmpty
                  ? 0
                  : 1;
              return Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.store, color: Colors.white),
                  ),
                  title: Text(
                    template.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'R\$ ${template.price.toStringAsFixed(2)} • $sheetCount Ficha(s)\n${template.tags.join(', ')}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SystemTemplateBuilderScreen(
                              repository: store,
                              template: template,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(
                          context,
                          template,
                          store,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SystemTemplateBuilderScreen(repository: store),
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NOVO PRODUTO'),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    StoreTemplate template,
    StoreRepository store,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir Produto?'),
        content: Text(
          "Tem certeza que deseja remover o treino '${template.name}' da Loja Oficial?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await store.deleteTemplate(template.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class SystemTemplateBuilderScreen extends StatefulWidget {
  const SystemTemplateBuilderScreen({
    super.key,
    required this.repository,
    this.template,
  });

  final StoreRepository repository;
  final StoreTemplate? template;

  @override
  State<SystemTemplateBuilderScreen> createState() =>
      _SystemTemplateBuilderScreenState();
}

class _SystemTemplateBuilderScreenState
    extends State<SystemTemplateBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0.00');
  final Map<String, List<WorkoutExercise>> _sheets = {'A': []};
  String _activeSheet = 'A';

  static const _availableTags = [
    'Hipertrofia',
    'Emagrecimento',
    'Condicionamento',
    'Iniciante',
    'Intermediário',
    'Avançado',
    'Casa',
    'Academia',
    'Sem Impacto',
  ];
  final List<String> _selectedTags = [];

  bool get _editing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template == null) return;
    _nameCtrl.text = template.name;
    _priceCtrl.text = template.price.toStringAsFixed(2);
    _selectedTags.addAll(template.tags);
    _sheets.clear();
    final source = template.sheets.isNotEmpty
        ? template.sheets
        : <String, List<Map<String, dynamic>>>{'A': template.legacyExercises};
    source.forEach((letter, exercises) {
      _sheets[letter] = exercises.map(WorkoutExercise.fromMap).toList();
    });
    if (_sheets.isEmpty) _sheets['A'] = [];
    _activeSheet = _sheets.keys.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _addSheet() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (final letter in alphabet.split('')) {
      if (!_sheets.containsKey(letter)) {
        setState(() {
          _sheets[letter] = [];
          _activeSheet = letter;
        });
        return;
      }
    }
  }

  void _removeSheet(String letter) {
    if (_sheets.length <= 1) return;
    setState(() {
      _sheets.remove(letter);
      _activeSheet = _sheets.keys.first;
    });
  }

  void _openCatalog() {
    var search = '';
    String? group;
    const groups = [
      'Peito',
      'Costas',
      'Pernas',
      'Ombros',
      'Bíceps',
      'Tríceps',
      'Abdômen',
      'Cardio',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) => setModalState(
                    () => search = value.toLowerCase().trim(),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Buscar exercício...',
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: group == null,
                      onSelected: (_) => setModalState(() => group = null),
                    ),
                    ...groups.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text(item),
                          selected: group == item,
                          onSelected: (_) =>
                              setModalState(() => group = group == item ? null : item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.redAccent),
                title: const Text(
                  'CRIAR NOVO EXERCÍCIO',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _createExerciseDialog();
                },
              ),
              Expanded(
                child: StreamBuilder<List<StoreExercise>>(
                  stream: widget.repository.watchExercises(),
                  builder: (context, snapshot) {
                    final exercises = (snapshot.data ?? const <StoreExercise>[])
                        .where((exercise) {
                          final nameMatch = search.isEmpty ||
                              exercise.name.toLowerCase().contains(search);
                          final groupMatch = group == null ||
                              exercise.group.toLowerCase() == group!.toLowerCase();
                          return nameMatch && groupMatch;
                        })
                        .toList(growable: false);
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
                          subtitle: Text(
                            exercise.group,
                            style: const TextStyle(color: Colors.white54),
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
            ],
          ),
        ),
      ),
    );
  }

  void _createExerciseDialog() {
    final nameCtrl = TextEditingController();
    final groupCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Novo Exercício Global'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl),
            TextField(controller: groupCtrl),
            TextField(controller: videoCtrl),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await widget.repository.saveExercise(
                name: nameCtrl.text,
                group: groupCtrl.text,
                videoUrl: videoCtrl.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      groupCtrl.dispose();
      videoCtrl.dispose();
    });
  }

  void _configureExercise(StoreExercise exercise) {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    final noteCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(exercise.name, style: const TextStyle(color: Colors.white)),
            Row(
              children: [
                Expanded(child: TextField(controller: seriesCtrl)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: repsCtrl)),
              ],
            ),
            TextField(controller: noteCtrl),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _sheets[_activeSheet]!.add(
                    WorkoutExercise(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      nome: exercise.name,
                      series: seriesCtrl.text,
                      repeticoes: repsCtrl.text,
                      videoUrl: exercise.videoUrl,
                      observacao: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.pop(sheetContext);
              },
              child: const Text('ADICIONAR À FICHA'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      seriesCtrl.dispose();
      repsCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  Future<void> _save() async {
    final hasExercise = _sheets.values.any((list) => list.isNotEmpty);
    if (_nameCtrl.text.trim().isEmpty || !hasExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e adicione exercícios!')),
      );
      return;
    }
    final sheets = <String, List<Map<String, dynamic>>>{};
    _sheets.forEach((letter, exercises) {
      sheets[letter] = exercises.map((item) => item.toMap()).toList();
    });
    await widget.repository.saveSystemTemplate(
      templateId: widget.template?.id,
      name: _nameCtrl.text,
      sheets: sheets,
      tags: _selectedTags,
      price: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _sheets[_activeSheet] ?? const <WorkoutExercise>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        foregroundColor: Colors.redAccent,
        title: Text(_editing ? 'Editar Produto' : 'Novo Produto'),
        actions: [
          IconButton(icon: const Icon(Icons.check_circle), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: _nameCtrl),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                Wrap(
                  spacing: 8,
                  children: _availableTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (value) => setState(() {
                        value ? _selectedTags.add(tag) : _selectedTags.remove(tag);
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _sheets.keys.map((letter) {
                      final active = letter == _activeSheet;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text('Ficha $letter'),
                          selected: active,
                          onSelected: (_) => setState(() => _activeSheet = letter),
                          onDeleted: _sheets.length > 1
                              ? () => _removeSheet(letter)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.redAccent),
                  onPressed: _addSheet,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openCatalog,
            icon: const Icon(Icons.add),
            label: Text('Adicionar Exercício (Ficha $_activeSheet)'),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return Card(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(
                      exercise.nome,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${exercise.series}x ${exercise.repeticoes}${exercise.observacao == null ? '' : '\nObs: ${exercise.observacao}'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(
                        () => _sheets[_activeSheet]!.removeAt(index),
                      ),
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

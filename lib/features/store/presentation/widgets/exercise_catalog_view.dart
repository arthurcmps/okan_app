import 'package:flutter/material.dart';

import '../../domain/entities/store_models.dart';

class ExerciseCatalogView extends StatefulWidget {
  const ExerciseCatalogView({
    super.key,
    required this.exercises,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StoreExercise> exercises;
  final bool canManage;
  final ValueChanged<StoreExercise> onEdit;
  final ValueChanged<StoreExercise> onDelete;

  @override
  State<ExerciseCatalogView> createState() => _ExerciseCatalogViewState();
}

class _ExerciseCatalogViewState extends State<ExerciseCatalogView> {
  static const _allGroups = '__all_groups__';

  final _searchController = TextEditingController();
  String? _selectedGroup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalized(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<String> get _groups {
    final groups = widget.exercises
        .map((exercise) => exercise.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (_selectedGroup != null && !groups.contains(_selectedGroup)) {
      groups.add(_selectedGroup!);
    }
    return groups;
  }

  List<StoreExercise> get _filteredExercises {
    final query = _normalized(_searchController.text);
    return widget.exercises.where((exercise) {
      final matchesQuery = query.isEmpty ||
          _normalized(exercise.name).contains(query) ||
          _normalized(exercise.group).contains(query);
      final matchesGroup =
          _selectedGroup == null || exercise.group.trim() == _selectedGroup;
      return matchesQuery && matchesGroup;
    }).toList(growable: false);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _selectedGroup = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredExercises;
    final hasFilters =
        _searchController.text.trim().isNotEmpty || _selectedGroup != null;

    return Column(
      children: [
        Container(
          key: ValueKey(
            widget.canManage
                ? 'exercise-catalog-admin'
                : 'exercise-catalog-read-only',
          ),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.canManage ? Icons.admin_panel_settings : Icons.info,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.canManage
                      ? 'Catálogo global. As alterações ficam disponíveis para '
                          'todos os usuários autenticados.'
                      : 'Este é o catálogo global da Okan. Professores podem '
                          'usá-lo nos próprios templates; somente a '
                          'administração altera os exercícios.',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            key: const ValueKey('exercise-catalog-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Buscar exercício',
              hintText: 'Nome ou grupo muscular',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Grupo muscular',
              prefixIcon: Icon(Icons.filter_list),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('exercise-catalog-group-filter'),
                value: _selectedGroup ?? _allGroups,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: _allGroups,
                    child: Text('Todos os grupos'),
                  ),
                  ..._groups.map(
                    (group) => DropdownMenuItem<String>(
                      value: group,
                      child: Text(group),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _selectedGroup = value == _allGroups ? null : value,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} de ${widget.exercises.length} exercícios',
                  key: const ValueKey('exercise-catalog-result-count'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (hasFilters)
                TextButton(
                  key: const ValueKey('exercise-catalog-clear-filters'),
                  onPressed: _clearFilters,
                  child: const Text('Limpar filtros'),
                ),
            ],
          ),
        ),
        Expanded(
          child: widget.exercises.isEmpty
              ? _EmptyCatalog(canManage: widget.canManage)
              : filtered.isEmpty
                  ? _FilteredEmpty(onClear: _clearFilters)
                  : ListView.builder(
                      key: const ValueKey('exercise-catalog-list'),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 104),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final exercise = filtered[index];
                        return _ExerciseCatalogCard(
                          exercise: exercise,
                          canManage: widget.canManage,
                          onEdit: () => widget.onEdit(exercise),
                          onDelete: () => widget.onDelete(exercise),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 44),
            const SizedBox(height: 12),
            Text(
              'Nenhum exercício cadastrado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Use “Novo exercício” para iniciar o catálogo global.'
                  : 'A administração ainda não adicionou exercícios ao catálogo.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 44),
            const SizedBox(height: 12),
            Text(
              'Nenhum exercício encontrado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCatalogCard extends StatelessWidget {
  const _ExerciseCatalogCard({
    required this.exercise,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final StoreExercise exercise;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVideo = exercise.videoUrl?.trim().isNotEmpty == true;

    return Card(
      key: ValueKey('exercise-catalog-${exercise.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.fitness_center),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.accessibility_new, size: 18),
                  label: Text(
                    exercise.group.trim().isEmpty ? 'Geral' : exercise.group,
                  ),
                ),
                if (hasVideo)
                  const Chip(
                    avatar: Icon(Icons.play_circle_outline, size: 18),
                    label: Text('Vídeo disponível'),
                  ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      key: ValueKey('exercise-catalog-edit-${exercise.id}'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      key: ValueKey('exercise-catalog-delete-${exercise.id}'),
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/widgets/okan_async_state.dart';
import '../../domain/entities/weekly_workout_plan.dart';

class WorkoutTemplateLibrary extends StatelessWidget {
  const WorkoutTemplateLibrary({
    super.key,
    required this.isLoading,
    required this.templates,
    required this.onImport,
    required this.onDelete,
    this.hasError = false,
    this.scrollController,
  });

  final bool isLoading;
  final bool hasError;
  final List<WorkoutTemplate> templates;
  final ValueChanged<WorkoutTemplate> onImport;
  final ValueChanged<WorkoutTemplate> onDelete;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              Text(
                'Minha Biblioteca',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque em um template para importar neste dia.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const OkanLoadingState(
                  label: 'Carregando biblioteca de templates',
                )
              : hasError
              ? const OkanMessageState(
                  key: ValueKey('workout-template-library-error'),
                  icon: Icons.cloud_off_outlined,
                  title: 'Não foi possível carregar a biblioteca',
                  description:
                      'Feche esta janela e tente novamente em alguns instantes.',
                  isError: true,
                  announce: true,
                )
              : templates.isEmpty
              ? const OkanMessageState(
                  key: ValueKey('workout-template-library-empty'),
                  icon: Icons.library_books_outlined,
                  title: 'Nenhum template salvo.',
                  description:
                      'Salve um dia de treino para encontrá-lo aqui.',
                )
              : ListView.builder(
                  key: const ValueKey('workout-template-library-list'),
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: templates.length,
                  itemBuilder: (_, index) {
                    final template = templates[index];
                    final exerciseCount = template.exercicios.length;
                    final exerciseLabel = exerciseCount == 1
                        ? '1 exercício'
                        : '$exerciseCount exercícios';

                    return Card(
                      key: ValueKey('workout-template-${template.id}'),
                      color: colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondary.withOpacity(
                            0.14,
                          ),
                          foregroundColor: colorScheme.secondary,
                          child: const Icon(Icons.fitness_center, size: 20),
                        ),
                        title: Text(
                          template.nome,
                          style: textTheme.titleMedium,
                        ),
                        subtitle: Text('$exerciseLabel • Toque para importar'),
                        trailing: IconButton(
                          key: ValueKey(
                            'workout-template-delete-${template.id}',
                          ),
                          tooltip: 'Excluir template',
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                          onPressed: () => onDelete(template),
                        ),
                        onTap: () => onImport(template),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

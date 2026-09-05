import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A ação visual principal da home quando existe treino no dia.
///
/// O widget não conhece Firebase nem navegação. O destino continua sendo
/// fornecido pela página, mantendo o contrato atual da home.
class HomeWorkoutCard extends StatelessWidget {
  const HomeWorkoutCard({
    required this.dayLabel,
    required this.exerciseCount,
    required this.firstExerciseName,
    required this.onTap,
    super.key,
  });

  final String dayLabel;
  final int exerciseCount;
  final String firstExerciseName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exerciseLabel = exerciseCount == 1
        ? '1 exercício'
        : '$exerciseCount exercícios';
    final exerciseName = firstExerciseName.trim().isEmpty
        ? 'Treino de hoje'
        : firstExerciseName.trim();

    return Semantics(
      button: true,
      label: 'Ver treino de hoje, $exerciseLabel, começando por $exerciseName',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.9),
                  AppColors.primary.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dayLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(Icons.fitness_center, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      exerciseLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exerciseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text(
                          'VER TREINO',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mantém os atalhos lado a lado quando existe espaço real para seus textos
/// e os empilha em telas estreitas, evitando truncamentos excessivos.
class HomeQuickActionsGrid extends StatelessWidget {
  const HomeQuickActionsGrid({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                Expanded(child: actions[index]),
                if (index < actions.length - 1) const SizedBox(width: 16),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              SizedBox(width: double.infinity, child: actions[index]),
              if (index < actions.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

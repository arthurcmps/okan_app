import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/data/repositories/firebase_workouts_repository.dart';
import '../../../workouts/domain/entities/workout_exercise.dart';
import '../../../workouts/domain/repositories/workouts_repository.dart';
import '../../data/repositories/firebase_store_repository.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';
import '../widgets/template_checkout_sheet.dart';

class DiscoverWorkoutsPage extends StatefulWidget {
  const DiscoverWorkoutsPage({
    super.key,
    this.storeRepository,
    this.workoutsRepository,
  });

  final StoreRepository? storeRepository;
  final WorkoutsRepository? workoutsRepository;

  @override
  State<DiscoverWorkoutsPage> createState() => _DiscoverWorkoutsPageState();
}

class _DiscoverWorkoutsPageState extends State<DiscoverWorkoutsPage> {
  late final StoreRepository _storeRepository;
  late final WorkoutsRepository _workoutsRepository;

  @override
  void initState() {
    super.initState();
    _storeRepository = widget.storeRepository ?? FirebaseStoreRepository();
    _workoutsRepository =
        widget.workoutsRepository ?? FirebaseWorkoutsRepository();
  }

  int _matchScore(StoreTemplate template, StoreUserState user) {
    var score = 0;
    for (final tag in template.tags) {
      if (user.tags.contains(tag)) score += 10;
    }
    return score;
  }

  Future<void> _acquire(StoreTemplate template, StoreUserState user) async {
    if (template.price <= 0) {
      try {
        await _storeRepository.acquireFreeTemplate(template.id);
        if (!mounted) return;
        _message(
          'Treino adicionado à sua Biblioteca! 🎉',
          AppColors.success,
        );
      } catch (error) {
        if (mounted) _message('Erro ao adquirir treino: $error', AppColors.error);
      }
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TemplateCheckoutSheet(
          template: template,
          payerEmail: user.email,
          repository: _storeRepository,
          onSuccess: () {
            if (mounted) {
              _message(
                'Pagamento aprovado. Treino liberado! 🎉',
                AppColors.success,
              );
            }
          },
        ),
      ),
    );
  }

  void _showTemplate(
    StoreTemplate template,
    StoreUserState user, {
    required bool acquired,
  }) {
    final sheets = template.sheets.isNotEmpty
        ? template.sheets
        : <String, List<Map<String, dynamic>>>{'A': template.legacyExercises};
    final letters = sheets.keys.toList()..sort();
    final score = acquired ? 0 : _matchScore(template, user);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (score > 0) ...[
                const SizedBox(height: 8),
                Text(
                  score >= 20
                      ? '🔥 Combinação Perfeita'
                      : '🔥 Recomendado para você',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Estrutura do Treino (${letters.length} Fichas):',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: letters.map((letter) {
                    final exercises = sheets[letter] ?? const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Ficha $letter',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ...exercises.map(
                          (exercise) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle,
                              color: AppColors.secondary,
                            ),
                            title: Text(
                              exercise['nome']?.toString() ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${exercise['series']}x ${exercise['repeticoes']}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (acquired) {
                      _chooseDays(template);
                    } else {
                      _acquire(template, user);
                    }
                  },
                  child: Text(
                    acquired
                        ? 'DISTRIBUIR NA MINHA SEMANA'
                        : template.price > 0
                        ? 'COMPRAR POR R\$ ${template.price.toStringAsFixed(2)}'
                        : 'ADICIONAR GRÁTIS',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _chooseDays(StoreTemplate template) {
    final sheets = template.sheets.isNotEmpty
        ? template.sheets
        : <String, List<Map<String, dynamic>>>{'A': template.legacyExercises};
    final letters = sheets.keys.toList()..sort();
    const dayKeys = [
      'segunda',
      'terca',
      'quarta',
      'quinta',
      'sexta',
      'sabado',
      'domingo',
    ];
    const dayNames = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    final selection = <String, String?>{for (final day in dayKeys) day: null};

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Distribuir na Semana',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: List.generate(dayKeys.length, (index) {
                final day = dayKeys[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayNames[index],
                      style: const TextStyle(color: Colors.white),
                    ),
                    DropdownButton<String?>(
                      value: selection[day],
                      dropdownColor: AppColors.background,
                      hint: const Text(
                        'Descanso',
                        style: TextStyle(color: Colors.white54),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Descanso'),
                        ),
                        ...letters.map(
                          (letter) => DropdownMenuItem<String?>(
                            value: letter,
                            child: Text('Ficha $letter'),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => selection[day] = value),
                    ),
                  ],
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selection.values.every((value) => value == null)
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _applyTemplate(sheets, selection);
                    },
              child: const Text('Aplicar Treino'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTemplate(
    Map<String, List<Map<String, dynamic>>> sheets,
    Map<String, String?> selection,
  ) async {
    final userId = _storeRepository.currentUserId;
    if (userId == null) return;
    final exercisesByDay = <String, List<WorkoutExercise>>{};

    for (final entry in selection.entries) {
      final sheet = entry.value;
      if (sheet == null) continue;
      final exercises = (sheets[sheet] ?? const []).map((raw) {
        final exercise = WorkoutExercise.fromMap(raw);
        exercise.id =
            '${DateTime.now().microsecondsSinceEpoch}${exercise.nome.hashCode}';
        exercise.concluido = false;
        return exercise;
      }).toList(growable: false);
      if (exercises.isNotEmpty) exercisesByDay[entry.key] = exercises;
    }

    try {
      await _workoutsRepository.appendWorkoutDays(
        studentId: userId,
        exercisesByDay: exercisesByDay,
      );
      if (mounted) {
        _message(
          'Treino aplicado com sucesso à sua semana! 💪',
          AppColors.primary,
        );
      }
    } catch (error) {
      if (mounted) _message('Erro ao aplicar: $error', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StoreUserState>(
      stream: _storeRepository.watchCurrentUser(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = userSnapshot.data!;
        return StreamBuilder<List<StoreTemplate>>(
          stream: _storeRepository.watchPremiumTemplates(),
          builder: (context, templatesSnapshot) {
            if (!templatesSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final all = templatesSnapshot.data!;
            final acquiredIds = user.purchasedTemplateIds.toSet();
            final store = all
                .where((template) => !acquiredIds.contains(template.id))
                .toList()
              ..sort((a, b) =>
                  _matchScore(b, user).compareTo(_matchScore(a, user)));
            final mine = all
                .where((template) => acquiredIds.contains(template.id))
                .toList(growable: false);

            return DefaultTabController(
              length: 2,
              child: Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  title: const Text('Loja de Treinos'),
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Explorar Loja', icon: Icon(Icons.storefront)),
                      Tab(
                        text: 'Meus Treinos',
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    _templateList(store, user, acquired: false),
                    _templateList(mine, user, acquired: true),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _templateList(
    List<StoreTemplate> templates,
    StoreUserState user, {
    required bool acquired,
  }) {
    if (templates.isEmpty) {
      return Center(
        child: Text(
          acquired
              ? 'Sua biblioteca está vazia.\nAdquira treinos na loja!'
              : 'Nenhum treino novo disponível no momento.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final score = acquired ? 0 : _matchScore(template, user);
        final sheetCount = template.sheets.isNotEmpty
            ? template.sheets.length
            : template.legacyExercises.isEmpty
            ? 0
            : 1;

        return GestureDetector(
          onTap: () => _showTemplate(template, user, acquired: acquired),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: score > 0
                  ? Border.all(color: AppColors.primary.withOpacity(0.5))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      acquired
                          ? 'ADQUIRIDO'
                          : score > 0
                          ? 'MATCH ALTO'
                          : 'DISPONÍVEL',
                      style: TextStyle(
                        color: acquired
                            ? AppColors.secondary
                            : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      acquired
                          ? 'PRONTO PARA USO'
                          : template.price > 0
                          ? 'R\$ ${template.price.toStringAsFixed(2)}'
                          : 'GRÁTIS',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  sheetCount > 0 ? '$sheetCount Ficha(s)' : 'Sem exercícios',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _message(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }
}

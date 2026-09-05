import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/time_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/video_player_page.dart';
import '../../data/repositories/firebase_workouts_repository.dart';
import '../../domain/entities/weekly_workout_plan.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_model.dart';
import '../../domain/repositories/workouts_repository.dart';
import '../widgets/workout_template_library.dart';

class WeeklyPlanPage extends StatefulWidget {
  const WeeklyPlanPage({
    super.key,
    required this.studentId,
    required this.studentName,
    this.repository,
  });

  final String studentId;
  final String studentName;
  final WorkoutsRepository? repository;

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage>
    with SingleTickerProviderStateMixin {
  static const _weekDays = <String>[
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
  ];

  static const _tabTitles = <String>['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  late final WorkoutsRepository _repository;
  late final TabController _tabController;
  final Map<String, List<WorkoutExercise>> _exerciseCache = {};
  final Map<String, TextEditingController> _feedbackControllers = {};

  bool _checkingProfile = true;
  bool _isProfessional = false;
  bool _editMode = false;
  bool _expiryNotificationScheduled = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwnWorkout => _currentUserId == widget.studentId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkoutsRepository();
    _tabController = TabController(
      length: _weekDays.length,
      vsync: this,
      initialIndex: DateTime.now().weekday - 1,
    );

    for (final day in _weekDays) {
      _feedbackControllers[day] = TextEditingController();
    }

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _checkingProfile = false);
      return;
    }

    try {
      final isProfessional = await _repository.isTrainingProfessional(userId);
      if (!mounted) return;

      setState(() {
        _isProfessional = isProfessional;
        _checkingProfile = false;
        if (!_isProfessional) {
          _editMode = false;
        } else if (!_isOwnWorkout) {
          _editMode = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _checkingProfile = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingProfile) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: StreamBuilder<WeeklyWorkoutPlan>(
        stream: _repository.watchWeeklyPlan(widget.studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final plan = snapshot.data!;
          _syncPlanCache(plan);
          _maybeNotifyValidity(plan);

          return Column(
            children: [
              _buildValidityBanner(plan),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _weekDays
                      .map((day) => _buildDayContent(day, plan.feedbackFor(day)))
                      .toList(growable: false),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _editMode
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _showAddOptions,
              tooltip: 'Opções',
              child: const Icon(Icons.add, color: Colors.black),
            )
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => TimerService.instance.start(60),
              icon: const Icon(Icons.timer_outlined, color: Colors.black),
              label: const Text(
                'Descanso 60s',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editMode ? 'Editar Treino' : 'Treino da Semana',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            widget.studentName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: [
        if (_editMode) ...[
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Limpar Dia',
            onPressed: () => _confirmClearDay(_currentDay),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.secondary),
            tooltip: 'Salvar dia como Template',
            onPressed: () => _showSaveTemplateDialog(_currentDay),
          ),
          if (!_isOwnWorkout)
            IconButton(
              icon: const Icon(Icons.send_to_mobile, color: AppColors.primary),
              tooltip: 'Avisar Aluno das Mudanças',
              onPressed: () => _notifyStudent(
                title: 'Treino Atualizado! 🏋️‍♂️',
                body:
                    'O seu professor acabou de atualizar a sua ficha de treinos. Vá dar uma olhada!',
              ),
            ),
        ],
        if (_isProfessional)
          IconButton(
            icon: Icon(
              _editMode ? Icons.check_circle : Icons.edit,
              color: _editMode ? AppColors.success : Colors.white,
            ),
            tooltip: _editMode ? 'Concluir Edição' : 'Editar Ficha',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.secondary,
        labelColor: AppColors.secondary,
        unselectedLabelColor: Colors.white38,
        indicatorWeight: 3,
        tabs: _tabTitles.map((title) => Tab(text: title)).toList(growable: false),
      ),
    );
  }

  String get _currentDay => _weekDays[_tabController.index];

  void _syncPlanCache(WeeklyWorkoutPlan plan) {
    for (final day in _weekDays) {
      _exerciseCache[day] = plan
          .exercisesFor(day)
          .map((exercise) => WorkoutExercise.fromMap(exercise.toMap()))
          .toList();

      final feedback = plan.feedbackFor(day);
      final controller = _feedbackControllers[day]!;
      if (controller.text.isEmpty && feedback.isNotEmpty) {
        controller.text = feedback;
      }
    }
  }

  Widget _buildDayContent(String dayKey, String currentFeedback) {
    final exercises = _exerciseCache[dayKey] ?? <WorkoutExercise>[];

    if (exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 60, color: Colors.white10),
            const SizedBox(height: 10),
            Text(
              _editMode
                  ? 'Toque no + para adicionar exercícios'
                  : 'Dia de Descanso. Recupere as energias!',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        ...exercises.map((exercise) => _buildExerciseCard(dayKey, exercise)),
        _buildFeedbackArea(dayKey, currentFeedback),
        if (!_editMode)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'FINALIZAR TREINO AQUI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () => _confirmCompleteWorkout(dayKey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseCard(String dayKey, WorkoutExercise exercise) {
    return Card(
      elevation: 4,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: exercise.solicitarAlteracao
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: exercise.concluido,
            activeColor: AppColors.secondary,
            checkColor: Colors.black,
            shape: const CircleBorder(),
            side: const BorderSide(color: Colors.white54),
            onChanged: _editMode
                ? null
                : (value) => _setExerciseCompleted(
                      dayKey,
                      exercise,
                      value ?? false,
                    ),
          ),
        ),
        title: Text(
          exercise.nome,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: exercise.concluido ? TextDecoration.lineThrough : null,
            color: exercise.concluido ? Colors.white24 : Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${exercise.series} x ${exercise.repeticoes}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  InkWell(
                    onTap: _editMode ? null : () => _showLoadDialog(dayKey, exercise),
                    borderRadius: BorderRadius.circular(4),
                    child: _pill(
                      icon: Icons.monitor_weight_outlined,
                      label: exercise.carga.isEmpty ? 'Carga?' : '${exercise.carga}kg',
                      color: AppColors.secondary,
                    ),
                  ),
                  if (exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty)
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerPage(
                            videoUrl: exercise.videoUrl!,
                            exerciseName: exercise.nome,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: _pill(
                        icon: Icons.play_circle_fill,
                        label: 'Vídeo',
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
              if (exercise.observacao != null &&
                  exercise.observacao!.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.observacao!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_editMode && _isOwnWorkout)
              IconButton(
                icon: Icon(
                  exercise.solicitarAlteracao
                      ? Icons.warning
                      : Icons.change_circle_outlined,
                  color: exercise.solicitarAlteracao
                      ? Colors.amber
                      : Colors.white30,
                ),
                tooltip: exercise.solicitarAlteracao
                    ? 'Alteração Solicitada'
                    : 'Solicitar Alteração',
                onPressed: () => _requestExerciseChange(dayKey, exercise),
              ),
            if (_editMode) ...[
              if (exercise.solicitarAlteracao)
                IconButton(
                  icon: const Icon(Icons.warning, color: Colors.redAccent),
                  tooltip: 'Marcar solicitação como resolvida',
                  onPressed: () {
                    setState(() => exercise.solicitarAlteracao = false);
                    _saveDay(dayKey);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white54),
                onPressed: () => _showEditExerciseDialog(dayKey, exercise),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeExercise(dayKey, exercise),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackArea(String dayKey, String currentFeedback) {
    if (_editMode) {
      if (currentFeedback.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(top: 20, bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: AppColors.secondary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Feedback do Aluno',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currentFeedback,
              style: const TextStyle(
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_isOwnWorkout && _isProfessional) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como foi o treino hoje?',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackControllers[dayKey],
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Senti dor no ombro... O treino foi muito longo... etc',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveFeedback(dayKey),
              icon: const Icon(Icons.send, color: AppColors.primary, size: 18),
              label: const Text(
                'Enviar Feedback para o Personal',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFeedback(String dayKey) async {
    final text = _feedbackControllers[dayKey]!.text.trim();
    if (text.isEmpty) return;

    await _repository.saveWorkoutFeedback(
      studentId: widget.studentId,
      dayKey: dayKey,
      feedback: text,
    );
    await _notifyPersonal(
      title: 'Feedback Novo 📝',
      body: '${widget.studentName} deixou um comentário no treino de $dayKey.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback enviado ao professor!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _setExerciseCompleted(
    String dayKey,
    WorkoutExercise exercise,
    bool completed,
  ) async {
    setState(() => exercise.concluido = completed);
    await _saveDay(dayKey);
  }

  Future<void> _saveDay(String dayKey) {
    return _repository.saveWorkoutDay(
      studentId: widget.studentId,
      dayKey: dayKey,
      exercises: _exerciseCache[dayKey] ?? <WorkoutExercise>[],
    );
  }

  Future<void> _removeExercise(String dayKey, WorkoutExercise exercise) async {
    setState(() {
      _exerciseCache[dayKey]?.removeWhere((item) => item.id == exercise.id);
    });
    await _saveDay(dayKey);
  }

  void _requestExerciseChange(String dayKey, WorkoutExercise exercise) {
    if (exercise.solicitarAlteracao) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Solicitar Alteração?', style: TextStyle(color: Colors.white)),
        content: Text(
          "Deseja pedir para o seu personal alterar o exercício '${exercise.nome}'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => exercise.solicitarAlteracao = true);
              await _saveDay(dayKey);
              await _notifyPersonal(
                title: 'Alteração Solicitada ⚠️',
                body:
                    "${widget.studentName} pediu para trocar o exercício '${exercise.nome}' ($dayKey).",
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solicitação enviada!')),
                );
              }
            },
            child: const Text(
              'Sim, pedir troca',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCompleteWorkout(String dayKey) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Concluir Treino?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Isso vai salvar o histórico de hoje e desmarcar os exercícios para a próxima semana.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(dialogContext);
              _completeWorkout(dayKey);
            },
            child: const Text(
              'Concluir',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeWorkout(String dayKey) async {
    final exercises = _exerciseCache[dayKey] ?? <WorkoutExercise>[];
    final feedback = _feedbackControllers[dayKey]?.text.trim() ?? '';

    try {
      await _repository.completeWorkoutDay(
        studentId: widget.studentId,
        dayKey: dayKey,
        exercises: exercises,
        feedback: feedback,
        clearPlanFeedback: true,
      );

      for (final exercise in exercises) {
        exercise.concluido = false;
      }
      _feedbackControllers[dayKey]!.clear();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino salvo no histórico! 💪'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $error')),
        );
      }
    }
  }

  void _showLoadDialog(String dayKey, WorkoutExercise exercise) {
    final controller = TextEditingController(text: exercise.carga);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Carga - ${exercise.nome}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Peso (kg)',
            suffixText: 'kg',
            labelStyle: TextStyle(color: Colors.white54),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              setState(() => exercise.carga = controller.text);
              await _saveDay(dayKey);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showEditExerciseDialog(String dayKey, WorkoutExercise exercise) {
    final name = TextEditingController(text: exercise.nome);
    final series = TextEditingController(text: exercise.series);
    final reps = TextEditingController(text: exercise.repeticoes);
    final video = TextEditingController(text: exercise.videoUrl ?? '');
    final observation = TextEditingController(text: exercise.observacao ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar Exercício', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogInput(name, 'Nome'),
              Row(
                children: [
                  Expanded(child: _dialogInput(series, 'Séries', number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _dialogInput(reps, 'Reps', number: true)),
                ],
              ),
              _dialogInput(video, 'Link do YouTube (Opcional)'),
              _dialogInput(observation, 'Observação para o Aluno (Opcional)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              setState(() {
                exercise.nome = name.text;
                exercise.series = series.text;
                exercise.repeticoes = reps.text;
                exercise.videoUrl = video.text.trim().isEmpty ? null : video.text.trim();
                exercise.observacao = observation.text.trim().isEmpty
                    ? null
                    : observation.text.trim();
                exercise.solicitarAlteracao = false;
              });
              await _saveDay(dayKey);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(
              'Salvar Alterações',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogInput(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text(
                  'Criar Manualmente',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddManualExerciseDialog(_currentDay);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: AppColors.primary),
                title: const Text(
                  'Importar da Biblioteca',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCatalog(_currentDay);
                },
              ),
              if (_isProfessional) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.library_books, color: AppColors.secondary),
                  title: const Text(
                    'Importar Template de Treino',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showTemplates(_currentDay);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddManualExerciseDialog(String dayKey) {
    final name = TextEditingController();
    final series = TextEditingController(text: '3');
    final reps = TextEditingController(text: '12');
    final video = TextEditingController();
    final observation = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Adicionar Exercício', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogInput(name, 'Nome do Exercício'),
              Row(
                children: [
                  Expanded(child: _dialogInput(series, 'Séries', number: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _dialogInput(reps, 'Repetições', number: true)),
                ],
              ),
              _dialogInput(video, 'Link do YouTube (Opcional)'),
              _dialogInput(observation, 'Observação para o Aluno (Opcional)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              if (name.text.trim().isEmpty) return;

              final exercise = WorkoutExercise(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                nome: name.text.trim(),
                series: series.text,
                repeticoes: reps.text,
                videoUrl: video.text.trim().isEmpty ? null : video.text.trim(),
                observacao:
                    observation.text.trim().isEmpty ? null : observation.text.trim(),
              );

              _exerciseCache.putIfAbsent(dayKey, () => <WorkoutExercise>[]).add(exercise);
              await _saveDay(dayKey);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) setState(() {});
            },
            child: const Text('Adicionar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showCatalog(String dayKey) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) => StreamBuilder<List<WorkoutCatalogExercise>>(
          stream: _repository.watchExerciseCatalog(),
          builder: (context, snapshot) {
            final exercises = snapshot.data ?? const <WorkoutCatalogExercise>[];
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Catálogo de Exercícios',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: exercises.length,
                          itemBuilder: (_, index) {
                            final exercise = exercises[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.black26,
                                child: Icon(
                                  Icons.fitness_center,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                exercise.nome,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                exercise.grupo,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _configureCatalogExercise(dayKey, exercise);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _configureCatalogExercise(String dayKey, WorkoutCatalogExercise catalog) {
    final series = TextEditingController(text: '3');
    final reps = TextEditingController(text: '12');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Configurar: ${catalog.nome}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Row(
          children: [
            Expanded(child: _dialogInput(series, 'Séries', number: true)),
            const SizedBox(width: 10),
            Expanded(child: _dialogInput(reps, 'Repetições', number: true)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final exercise = WorkoutExercise(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                nome: catalog.nome,
                series: series.text,
                repeticoes: reps.text,
                videoUrl: catalog.videoUrl.isEmpty ? null : catalog.videoUrl,
              );
              _exerciseCache.putIfAbsent(dayKey, () => <WorkoutExercise>[]).add(exercise);
              await _saveDay(dayKey);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) setState(() {});
            },
            child: const Text(
              'Adicionar à Ficha',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveTemplateDialog(String dayKey) {
    final exercises = _exerciseCache[dayKey] ?? <WorkoutExercise>[];
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione exercícios primeiro!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final name = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Salvar na Biblioteca', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: name,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nome (ex: Ficha A - Hipertrofia)',
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              final userId = _currentUserId;
              if (userId == null || name.text.trim().isEmpty) return;

              await _repository.saveWorkoutTemplate(
                personalId: userId,
                nome: name.text,
                exercises: exercises,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Template salvo na biblioteca!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showTemplates(String dayKey) {
    final userId = _currentUserId;
    if (userId == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollController) => StreamBuilder<List<WorkoutTemplate>>(
          stream: _repository.watchWorkoutTemplates(userId),
          builder: (context, snapshot) {
            final templates = snapshot.data ?? const <WorkoutTemplate>[];
            return WorkoutTemplateLibrary(
              isLoading:
                  snapshot.connectionState == ConnectionState.waiting,
              templates: templates,
              scrollController: scrollController,
              onDelete: (template) =>
                  _repository.deleteWorkoutTemplate(template.id),
              onImport: (template) async {
                final imported = template.exercicios.map((exercise) {
                  final copy = WorkoutExercise.fromMap(exercise.toMap());
                  copy.id =
                      '${DateTime.now().microsecondsSinceEpoch}${copy.nome.hashCode}';
                  copy.concluido = false;
                  return copy;
                }).toList();

                _exerciseCache
                    .putIfAbsent(dayKey, () => <WorkoutExercise>[])
                    .addAll(imported);
                await _saveDay(dayKey);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template importado com sucesso!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _confirmClearDay(String dayKey) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Limpar Dia?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tem certeza que deseja apagar todos os exercícios deste dia? Isso não pode ser desfeito.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _exerciseCache[dayKey] = <WorkoutExercise>[]);
              await _saveDay(dayKey);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Treino do dia apagado com sucesso!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidityBanner(WeeklyWorkoutPlan plan) {
    final validity = plan.validade;
    if (validity == null && !_editMode) return const SizedBox.shrink();

    var background = AppColors.surface;
    var textColor = Colors.white70;
    var icon = Icons.date_range;
    var label = validity == null
        ? 'Sem validade definida (Toque para adicionar)'
        : 'Válido até: ${_formatDate(validity)}';

    if (validity != null) {
      final difference = _daysUntil(validity);
      if (difference < 0) {
        background = Colors.redAccent.withOpacity(0.2);
        textColor = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        label = 'Treino Vencido! (Expirou em ${_formatDate(validity)})';
      } else if (difference <= 3) {
        background = Colors.amber.withOpacity(0.2);
        textColor = Colors.amber;
        icon = Icons.timer_outlined;
        label = 'Vence em $difference dias! (${_formatDate(validity)})';
      }
    }

    return GestureDetector(
      onTap: _editMode ? _chooseValidity : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            if (_editMode) ...[
              const SizedBox(width: 8),
              const Icon(Icons.edit, color: Colors.white54, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseValidity() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            onPrimary: Colors.black,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (selected == null) return;
    await _repository.setWorkoutValidity(
      studentId: widget.studentId,
      validade: selected,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validade do treino definida com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _maybeNotifyValidity(WeeklyWorkoutPlan plan) {
    final validity = plan.validade;
    if (validity == null || plan.avisadoVencimento || _expiryNotificationScheduled) {
      return;
    }

    final difference = _daysUntil(validity);
    if (difference > 3) return;

    _expiryNotificationScheduled = true;
    Future.microtask(() async {
      try {
        await _repository.markExpiryWarningSent(widget.studentId);
        if (difference < 0) {
          await _notifyStudent(
            title: 'Treino Vencido! 🚨',
            body:
                'A validade da sua ficha expirou. Cobre seu personal para novos estímulos!',
          );
          await _notifyPersonal(
            title: 'Treino Vencido 🚨',
            body: 'A ficha de ${widget.studentName} expirou. É hora de renovar!',
          );
        } else {
          await _notifyStudent(
            title: 'Treino Vencendo! ⏳',
            body: 'Sua ficha vence em $difference dias. Avise seu personal!',
          );
          await _notifyPersonal(
            title: 'Treino Vencendo ⏳',
            body: 'A ficha de ${widget.studentName} vence em $difference dias.',
          );
        }
      } catch (error) {
        debugPrint('Erro ao notificar validade do treino: $error');
        _expiryNotificationScheduled = false;
      }
    });
  }

  Future<void> _notifyStudent({required String title, required String body}) async {
    final actionId = _currentUserId;
    if (actionId == null) return;

    try {
      await _repository.notifyUser(
        userId: widget.studentId,
        type: 'workout_update',
        title: title,
        body: body,
        actionId: actionId,
      );
    } catch (error) {
      debugPrint('Erro ao notificar aluno: $error');
    }
  }

  Future<void> _notifyPersonal({required String title, required String body}) async {
    if (_isOwnWorkout && _isProfessional) return;

    try {
      final professionalId =
          await _repository.findStudentProfessionalId(widget.studentId);
      if (professionalId == null || professionalId == 'SYSTEM_ADMIN') return;

      await _repository.notifyUser(
        userId: professionalId,
        type: 'workout',
        title: title,
        body: body,
        actionId: widget.studentId,
      );
    } catch (error) {
      debugPrint('Erro ao notificar personal: $error');
    }
  }

  int _daysUntil(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.difference(todayOnly).inDays;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

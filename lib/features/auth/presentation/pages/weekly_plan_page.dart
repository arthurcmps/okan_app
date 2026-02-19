import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; 
import '../../data/models/workout_plans_model.dart'; 

class WeeklyPlanPage extends StatefulWidget {
  final String studentId; 
  final String studentName; 

  const WeeklyPlanPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _diasDaSemana = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
  final List<String> _titulosAbas = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  final Map<String, List<WorkoutExercise>> _cacheExercicios = {};
  
  // Controladores para o campo de feedback de cada dia
  final Map<String, TextEditingController> _feedbackControllers = {};

  bool get _souPersonal {
    final meuId = FirebaseAuth.instance.currentUser?.uid;
    return meuId != widget.studentId;
  }

  @override
  void initState() {
    super.initState();
    int diaHoje = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, vsync: this, initialIndex: diaHoje);
    
    for (var dia in _diasDaSemana) {
      _feedbackControllers[dia] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var ctrl in _feedbackControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // --- LÓGICA DE NOTIFICAÇÃO ---
  Future<void> _notificarPersonal(String titulo, String corpo) async {
    try {
      // 1. Acha o ID do personal vinculado a este aluno
      final docAluno = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
      final personalId = docAluno.data()?['personalId'];
      
      if (personalId == null) return; // Se não tem personal, não faz nada

      // 2. Cria a notificação para o Personal
      await FirebaseFirestore.instance
          .collection('users')
          .doc(personalId)
          .collection('notifications')
          .add({
        'type': 'workout',
        'title': titulo,
        'body': corpo,
        'actionId': widget.studentId, // ID do aluno para o personal clicar e ir pro perfil
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erro ao notificar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white, 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _souPersonal ? "Editar Treino" : "Treino da Semana",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(widget.studentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.secondary, 
          labelColor: AppColors.secondary,
          unselectedLabelColor: Colors.white38,
          indicatorWeight: 3,
          tabs: _titulosAbas.map((dia) => Tab(text: dia)).toList(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_plans')
            .doc(widget.studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

          final data = snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};

          return TabBarView(
            controller: _tabController,
            children: _diasDaSemana.map((diaKey) {
              final listaRaw = data[diaKey] as List<dynamic>? ?? [];
              final exercicios = listaRaw.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>)).toList();
              _cacheExercicios[diaKey] = exercicios;

              // Pega o feedback atual do banco
              final feedbackAtual = data['feedback_$diaKey'] as String? ?? '';
              
              // Se o controlador estiver vazio e tiver texto no banco (primeiro load), a gente preenche
              if (_feedbackControllers[diaKey]!.text.isEmpty && feedbackAtual.isNotEmpty) {
                 _feedbackControllers[diaKey]!.text = feedbackAtual;
              }

              return _buildDiaContent(diaKey, exercicios, feedbackAtual);
            }).toList(),
          );
        },
      ),
      floatingActionButton: _souPersonal
          ? FloatingActionButton(
              backgroundColor: AppColors.primary, 
              onPressed: _adicionarExercicioDialog,
              child: const Icon(Icons.add, color: Colors.black), // Ícone preto no botão neon
            )
          : null,
    );
  }

  Widget _buildDiaContent(String diaKey, List<WorkoutExercise> exercicios, String feedbackAtual) {
    if (exercicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 60, color: Colors.white10),
            const SizedBox(height: 10),
            Text(
              _souPersonal ? "Toque no + para adicionar" : "Descanso.", 
              style: const TextStyle(color: Colors.white38)
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // LISTA DE EXERCÍCIOS
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercicios.length + 1, // +1 para a área de Feedback no final
            itemBuilder: (context, index) {
              
              // Se for o último item, renderiza a área de Feedback
              if (index == exercicios.length) {
                return _buildFeedbackArea(diaKey, feedbackAtual);
              }

              final ex = exercicios[index];
              return Card(
                elevation: 4,
                color: AppColors.surface, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    // Borda fica vermelha se o aluno pediu alteração
                    color: ex.solicitarAlteracao ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  
                  // CHECKBOX
                  leading: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: ex.concluido,
                      activeColor: AppColors.secondary, 
                      checkColor: Colors.black,
                      shape: const CircleBorder(),
                      side: const BorderSide(color: Colors.white54),
                      onChanged: (val) => _atualizarStatusExercicio(diaKey, ex, val ?? false),
                    ),
                  ),
                  
                  // NOME DO EXERCÍCIO
                  title: Text(
                    ex.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ex.concluido ? TextDecoration.lineThrough : null,
                      color: ex.concluido ? Colors.white24 : Colors.white,
                    ),
                  ),
                  
                  // SÉRIES E REPETIÇÕES
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Text("${ex.series} x ${ex.repeticoes}", style: const TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        
                        // CARGA
                        InkWell(
                          onTap: () => _editarCargaDialog(diaKey, ex),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black26, 
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.monitor_weight_outlined, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  ex.carga.isEmpty ? "Carga?" : "${ex.carga}kg",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ex.carga.isEmpty ? AppColors.primary : Colors.white
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // AÇÕES (Personal ou Aluno)
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SE FOR ALUNO: Ícone de solicitar alteração
                      if (!_souPersonal)
                        IconButton(
                          icon: Icon(
                            ex.solicitarAlteracao ? Icons.warning : Icons.change_circle_outlined,
                            color: ex.solicitarAlteracao ? Colors.amber : Colors.white30,
                          ),
                          tooltip: ex.solicitarAlteracao ? "Alteração Solicitada" : "Solicitar Alteração",
                          onPressed: () => _solicitarAlteracao(diaKey, ex),
                        ),

                      // SE FOR PERSONAL: Ícones de edição
                      if (_souPersonal) ...[
                        if (ex.solicitarAlteracao)
                           IconButton(
                            icon: const Icon(Icons.warning, color: Colors.redAccent),
                            tooltip: "Aluno pediu para trocar. Clique para resolver.",
                            onPressed: () {
                              setState(() => ex.solicitarAlteracao = false);
                              _salvarListaDoDia(diaKey);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white54),
                          onPressed: () => _editarExercicioCompletoDialog(diaKey, ex),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removerExercicio(diaKey, ex),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // BOTÃO DE FINALIZAR TREINO (SÓ PARA O ALUNO)
        if (!_souPersonal && exercicios.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success, 
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                icon: const Icon(Icons.check_circle, color: Colors.black),
                label: const Text("FINALIZAR TREINO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                onPressed: () => _confirmarFinalizacao(diaKey),
              ),
            ),
          ),
      ],
    );
  }

  // --- ÁREA DE FEEDBACK ---
  Widget _buildFeedbackArea(String diaKey, String feedbackAtual) {
    if (_souPersonal) {
      // PERSONAL: Apenas visualiza o feedback
      if (feedbackAtual.isEmpty) return const SizedBox.shrink(); // Se não tem feedback, esconde
      
      return Container(
        margin: const EdgeInsets.only(top: 20, bottom: 80), // Margem extra por causa do FAB
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.5))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: AppColors.secondary, size: 18),
                SizedBox(width: 8),
                Text("Feedback do Aluno", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(feedbackAtual, style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    // ALUNO: Campo para digitar o feedback
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Como foi o treino hoje?", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackControllers[diaKey],
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Senti dor no ombro... O treino foi muito longo... etc",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _salvarFeedback(diaKey),
              icon: const Icon(Icons.send, color: AppColors.primary, size: 18),
              label: const Text("Enviar Feedback", style: TextStyle(color: AppColors.primary)),
            ),
          )
        ],
      ),
    );
  }

  // --- LÓGICA DE FEEDBACK E SOLICITAÇÃO ---
  Future<void> _salvarFeedback(String diaKey) async {
    final texto = _feedbackControllers[diaKey]!.text.trim();
    if (texto.isEmpty) return;

    // Salva no banco no documento do treino
    await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(widget.studentId)
        .set({'feedback_$diaKey': texto}, SetOptions(merge: true));

    // Notifica o Personal
    await _notificarPersonal(
      "Feedback Novo 📝", 
      "${widget.studentName} deixou um comentário no treino de $diaKey."
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback enviado ao professor!"), backgroundColor: AppColors.success));
    }
  }

  void _solicitarAlteracao(String diaKey, WorkoutExercise ex) {
    if (ex.solicitarAlteracao) return; // Já solicitou

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Solicitar Alteração?", style: TextStyle(color: Colors.white)),
        content: Text("Deseja pedir para o seu personal alterar o exercício '${ex.nome}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => ex.solicitarAlteracao = true);
              await _salvarListaDoDia(diaKey);
              
              await _notificarPersonal(
                "Alteração Solicitada ⚠️", 
                "${widget.studentName} pediu para trocar o exercício '${ex.nome}' ($diaKey)."
              );

              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitação enviada!")));
            },
            child: const Text("Sim, pedir troca", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- LÓGICA DE FINALIZAR TREINO ---
  void _confirmarFinalizacao(String diaKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Concluir Treino?", style: TextStyle(color: Colors.white)),
        content: const Text("Isso vai salvar o histórico de hoje e desmarcar os exercícios para a próxima semana.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(context);
              _salvarHistoricoEResetar(diaKey);
            },
            child: const Text("Concluir", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _salvarHistoricoEResetar(String diaKey) async {
    final exerciciosAtuais = _cacheExercicios[diaKey] ?? [];
    
    try {
      await FirebaseFirestore.instance.collection('workout_history').add({
        'studentId': widget.studentId,
        'diaDaSemana': diaKey,
        'dataRealizacao': FieldValue.serverTimestamp(),
        'exercicios': exerciciosAtuais.map((e) => e.toMap()).toList(),
      });

      for (var ex in exerciciosAtuais) {
        ex.concluido = false;
      }
      
      _cacheExercicios[diaKey] = exerciciosAtuais;
      await _salvarListaDoDia(diaKey);

      // Limpa o feedback do dia para a próxima semana
      _feedbackControllers[diaKey]!.clear();
      await FirebaseFirestore.instance.collection('workout_plans').doc(widget.studentId).update({
        'feedback_$diaKey': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino salvo no histórico! 💪"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    }
  }

  // --- LÓGICA DE SALVAMENTO ---
  Future<void> _salvarListaDoDia(String diaKey) async {
    final listaExercicios = _cacheExercicios[diaKey] ?? [];
    final listaParaSalvar = listaExercicios.map((e) => e.toMap()).toList();
    
    await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(widget.studentId)
        .set({diaKey: listaParaSalvar}, SetOptions(merge: true));
  }

  void _atualizarStatusExercicio(String diaKey, WorkoutExercise ex, bool status) {
    setState(() {
      ex.concluido = status;
    });
    _salvarListaDoDia(diaKey);
  }

  // --- MODAIS DE EDIÇÃO ---
  void _editarCargaDialog(String diaKey, WorkoutExercise ex) {
    final cargaCtrl = TextEditingController(text: ex.carga);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Carga - ${ex.nome}", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: cargaCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Peso (kg)", suffixText: "kg",
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              setState(() => ex.carga = cargaCtrl.text);
              _salvarListaDoDia(diaKey);
              Navigator.pop(context);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  void _editarExercicioCompletoDialog(String diaKey, WorkoutExercise ex) {
    final nomeCtrl = TextEditingController(text: ex.nome);
    final seriesCtrl = TextEditingController(text: ex.series);
    final repsCtrl = TextEditingController(text: ex.repeticoes);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Editar Exercício", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(nomeCtrl, "Nome"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDialogInput(seriesCtrl, "Séries", isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildDialogInput(repsCtrl, "Reps", isNumber: true)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                ex.nome = nomeCtrl.text;
                ex.series = seriesCtrl.text;
                ex.repeticoes = repsCtrl.text;
                // Quando o personal edita, assumimos que ele atendeu a solicitação e apagamos o alerta
                ex.solicitarAlteracao = false; 
              });
              _salvarListaDoDia(diaKey);
              Navigator.pop(context);
            },
            child: const Text("Salvar Alterações", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _adicionarExercicioDialog() {
    final nomeCtrl = TextEditingController();
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Adicionar Exercício", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(nomeCtrl, "Nome do Exercício"),
            Row(
              children: [
                Expanded(child: _buildDialogInput(seriesCtrl, "Séries", isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildDialogInput(repsCtrl, "Repetições", isNumber: true)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              if (nomeCtrl.text.isNotEmpty) {
                final novo = WorkoutExercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nome: nomeCtrl.text,
                  series: seriesCtrl.text,
                  repeticoes: repsCtrl.text,
                );
                
                final diaAtual = _diasDaSemana[_tabController.index];
                List<WorkoutExercise> lista = _cacheExercicios[diaAtual] ?? [];
                lista.add(novo);
                _cacheExercicios[diaAtual] = lista;
                
                await _salvarListaDoDia(diaAtual);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Adicionar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String label, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      ),
    );
  }

  Future<void> _removerExercicio(String diaKey, WorkoutExercise ex) async {
    setState(() {
      if (_cacheExercicios[diaKey] != null) {
        _cacheExercicios[diaKey]!.removeWhere((element) => element.id == ex.id);
      }
    });
    await _salvarListaDoDia(diaKey);
  }
}
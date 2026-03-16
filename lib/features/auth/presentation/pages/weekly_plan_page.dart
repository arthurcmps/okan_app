import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; 
import '../../data/models/workout_plans_model.dart'; 
import '../../../../core/services/time_service.dart';

import 'video_player_page.dart';

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
  final Map<String, TextEditingController> _feedbackControllers = {};

  bool _isVerificandoPerfil = true;
  bool _souProfessor = false;
  bool _isAlunoSemPersonal = false; 
  bool _modoEdicao = false;

  bool get _isMeuProprioTreino => FirebaseAuth.instance.currentUser?.uid == widget.studentId;

  @override
  void initState() {
    super.initState();
    int diaHoje = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, vsync: this, initialIndex: diaHoje);
    
    for (var dia in _diasDaSemana) {
      _feedbackControllers[dia] = TextEditingController();
    }

    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    if (!_isMeuProprioTreino) {
      if (mounted) {
        setState(() {
          _souProfessor = true;
          _modoEdicao = true; 
          _isVerificandoPerfil = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
      final data = doc.data();
      
      bool isProf = false;
      bool isSelfManaged = false;

      if (data != null) {
        final role = data['role']?.toString().toLowerCase();
        final tipo = data['tipo']?.toString().toLowerCase();
        final isPersonal = data['isPersonal'] == true;
        
        if (role == 'personal' || role == 'professor' || tipo == 'personal' || isPersonal) {
          isProf = true;
        }

        final pId = data['personalId'];
        if (!isProf && (pId == null || pId.toString().trim().isEmpty)) {
          isSelfManaged = true;
        }
      }
      
      if (mounted) {
        setState(() {
          _souProfessor = isProf;
          _isAlunoSemPersonal = isSelfManaged; 
          _modoEdicao = false; 
          _isVerificandoPerfil = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isVerificandoPerfil = false);
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

  Future<void> _notificarPersonal(String titulo, String corpo) async {
    if (_isMeuProprioTreino && _souProfessor) return;
    if (_isAlunoSemPersonal) return; 

    try {
      final docAluno = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
      final personalId = docAluno.data()?['personalId'];
        
      if (personalId == null || personalId.toString().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(personalId)
          .collection('notifications')
          .add({
        'type': 'workout',
        'title': titulo,
        'body': corpo,
        'actionId': widget.studentId, 
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erro ao notificar: $e");
    }
  }

  Future<void> _notificarAluno(String titulo, String corpo) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('notifications')
          .add({
        'type': 'workout_update',
        'title': titulo,
        'body': corpo,
        'actionId': FirebaseAuth.instance.currentUser!.uid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O aluno foi notificado do novo treino!"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      debugPrint("Erro ao notificar aluno: $e");
    }
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _limparDiaDialog(String diaKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Limpar Dia?", style: TextStyle(color: Colors.white)),
        content: const Text("Tem certeza que deseja apagar todos os exercícios deste dia? Isso não pode ser desfeito.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx); // Fecha o dialog com segurança
              setState(() {
                _cacheExercicios[diaKey] = [];
              });
              await _salvarListaDoDia(diaKey);
              if (mounted) {
                // Usa o context original da página para o SnackBar
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino do dia apagado com sucesso!"), backgroundColor: AppColors.success));
              }
            },
            child: const Text("Limpar Tudo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerificandoPerfil) {
      return const Scaffold(
        backgroundColor: AppColors.background, 
        body: Center(child: CircularProgressIndicator(color: AppColors.secondary))
      );
    }

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
              _modoEdicao ? "Editar Treino" : "Treino da Semana",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(widget.studentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_modoEdicao)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: "Limpar Dia",
              onPressed: () {
                _limparDiaDialog(_diasDaSemana[_tabController.index]);
              },
            ),

          if ((_souProfessor || _isAlunoSemPersonal) && _isMeuProprioTreino)
            IconButton(
              icon: Icon(_modoEdicao ? Icons.visibility : Icons.edit, color: AppColors.primary),
              tooltip: _modoEdicao ? "Mudar para Modo Treino" : "Mudar para Modo Edição",
              onPressed: () {
                setState(() {
                  _modoEdicao = !_modoEdicao;
                });
              },
            ),

          if (_modoEdicao && _souProfessor)
            IconButton(
              icon: const Icon(Icons.save_outlined, color: AppColors.secondary),
              tooltip: "Salvar dia como Template",
              onPressed: () {
                _salvarComoTemplateDialog(_diasDaSemana[_tabController.index]);
              },
            ),

          if (_modoEdicao && !_isMeuProprioTreino)
            IconButton(
              icon: const Icon(Icons.send_to_mobile, color: AppColors.primary),
              tooltip: "Avisar Aluno das Mudanças",
              onPressed: () {
                _notificarAluno("Treino Atualizado! 🏋️‍♂️", "O seu professor acabou de atualizar a sua ficha de treinos. Vá dar uma olhada!");
              },
            ),
        ],
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

              final feedbackAtual = data['feedback_$diaKey'] as String? ?? '';
              
              if (_feedbackControllers[diaKey]!.text.isEmpty && feedbackAtual.isNotEmpty) {
                 _feedbackControllers[diaKey]!.text = feedbackAtual;
              }

              return _buildDiaContent(diaKey, exercicios, feedbackAtual);
            }).toList(),
          );
        },
      ),
      
      floatingActionButton: _modoEdicao
          ? FloatingActionButton(
              backgroundColor: AppColors.primary, 
              onPressed: _mostrarOpcoesAdicionar,
              tooltip: "Opções",
              child: const Icon(Icons.add, color: Colors.black), 
            )
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => TimerService.instance.start(60),
              icon: const Icon(Icons.timer_outlined, color: Colors.black),
              label: const Text(
                "Descanso 60s", 
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
              ),
            ),
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
              _modoEdicao ? "Toque no + para adicionar exercícios" : "Dia de Descanso. Recupere as energias!", 
              style: const TextStyle(color: Colors.white38)
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercicios.length + 2, 
            itemBuilder: (context, index) {
              
              if (index == exercicios.length) {
                return _buildFeedbackArea(diaKey, feedbackAtual);
              }

              if (index == exercicios.length + 1) {
                if (_modoEdicao) {
                  return const SizedBox(height: 80); 
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 100.0), 
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
                );
              }

              final ex = exercicios[index];
              return Card(
                elevation: 4,
                color: AppColors.surface, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: ex.solicitarAlteracao ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  
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
                  
                  title: Text(
                    ex.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ex.concluido ? TextDecoration.lineThrough : null,
                      color: ex.concluido ? Colors.white24 : Colors.white,
                    ),
                  ),
                  
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 12, 
                      runSpacing: 8, 
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("${ex.series} x ${ex.repeticoes}", style: const TextStyle(color: Colors.white70)),
                        
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
                              mainAxisSize: MainAxisSize.min,
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
                        
                        if (ex.videoUrl != null && ex.videoUrl!.isNotEmpty)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(videoUrl: ex.videoUrl!, exerciseName: ex.nome)
                                )
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15), 
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  Text("Vídeo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_modoEdicao && !_isMeuProprioTreino && !_isAlunoSemPersonal)
                        IconButton(
                          icon: Icon(
                            ex.solicitarAlteracao ? Icons.warning : Icons.change_circle_outlined,
                            color: ex.solicitarAlteracao ? Colors.amber : Colors.white30,
                          ),
                          tooltip: ex.solicitarAlteracao ? "Alteração Solicitada" : "Solicitar Alteração",
                          onPressed: () => _solicitarAlteracao(diaKey, ex),
                        ),

                      if (_modoEdicao) ...[
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
      ],
    );
  }

  Widget _buildFeedbackArea(String diaKey, String feedbackAtual) {
    if (_modoEdicao) {
      if (feedbackAtual.isEmpty) return const SizedBox.shrink(); 
      
      return Container(
        margin: const EdgeInsets.only(top: 20, bottom: 10), 
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

    if ((_isMeuProprioTreino && _souProfessor) || _isAlunoSemPersonal) {
      return const SizedBox.shrink();
    }

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

  Future<void> _salvarFeedback(String diaKey) async {
    final texto = _feedbackControllers[diaKey]!.text.trim();
    if (texto.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(widget.studentId)
        .set({'feedback_$diaKey': texto}, SetOptions(merge: true));

    await _notificarPersonal(
      "Feedback Novo 📝", 
      "${widget.studentName} deixou um comentário no treino de $diaKey."
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback enviado ao professor!"), backgroundColor: AppColors.success));
    }
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _solicitarAlteracao(String diaKey, WorkoutExercise ex) {
    if (ex.solicitarAlteracao) return; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Solicitar Alteração?", style: TextStyle(color: Colors.white)),
        content: Text("Deseja pedir para o seu personal alterar o exercício '${ex.nome}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              Navigator.pop(ctx);
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

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _confirmarFinalizacao(String diaKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Concluir Treino?", style: TextStyle(color: Colors.white)),
        content: const Text("Isso vai salvar o histórico de hoje e desmarcar os exercícios para a próxima semana.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(ctx);
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

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _editarCargaDialog(String diaKey, WorkoutExercise ex) {
    final cargaCtrl = TextEditingController(text: ex.carga);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              setState(() => ex.carga = cargaCtrl.text);
              _salvarListaDoDia(diaKey);
              Navigator.pop(ctx);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _editarExercicioCompletoDialog(String diaKey, WorkoutExercise ex) {
    final nomeCtrl = TextEditingController(text: ex.nome);
    final seriesCtrl = TextEditingController(text: ex.series);
    final repsCtrl = TextEditingController(text: ex.repeticoes);
    final videoCtrl = TextEditingController(text: ex.videoUrl ?? ''); 
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Editar Exercício", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
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
              ),
              const SizedBox(height: 10),
              _buildDialogInput(videoCtrl, "Link do YouTube (Opcional)"), 
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                ex.nome = nomeCtrl.text;
                ex.series = seriesCtrl.text;
                ex.repeticoes = repsCtrl.text;
                ex.videoUrl = videoCtrl.text.trim(); 
                ex.solicitarAlteracao = false; 
              });
              _salvarListaDoDia(diaKey);
              Navigator.pop(ctx);
            },
            child: const Text("Salvar Alterações", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _adicionarExercicioDialog() {
    final nomeCtrl = TextEditingController();
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    final videoCtrl = TextEditingController(); 
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Adicionar Exercício", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInput(nomeCtrl, "Nome do Exercício"),
              Row(
                children: [
                  Expanded(child: _buildDialogInput(seriesCtrl, "Séries", isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDialogInput(repsCtrl, "Repetições", isNumber: true)),
                ],
              ),
              const SizedBox(height: 10),
              _buildDialogInput(videoCtrl, "Link do YouTube (Opcional)"), 
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              if (nomeCtrl.text.isNotEmpty) {
                final novo = WorkoutExercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nome: nomeCtrl.text,
                  series: seriesCtrl.text,
                  repeticoes: repsCtrl.text,
                  videoUrl: videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim(), 
                );
                
                final diaAtual = _diasDaSemana[_tabController.index];
                List<WorkoutExercise> lista = _cacheExercicios[diaAtual] ?? [];
                lista.add(novo);
                _cacheExercicios[diaAtual] = lista;
                
                await _salvarListaDoDia(diaAtual);
                if (mounted) Navigator.pop(ctx);
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

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _mostrarOpcoesAdicionar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text("Criar Manualmente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Digitar um exercício do zero", style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _adicionarExercicioDialog(); 
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: AppColors.primary),
                title: const Text("Importar da Biblioteca", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Escolher um exercício do catálogo global", style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _importarExercicioDaBibliotecaDialog(_diasDaSemana[_tabController.index]);
                },
              ),
              
              if (_souProfessor) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.library_books, color: AppColors.secondary),
                  title: const Text("Importar Template de Treino", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Copiar uma lista de exercícios pronta", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importarTemplateDialog(_diasDaSemana[_tabController.index]);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _importarExercicioDaBibliotecaDialog(String diaKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx2, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Catálogo de Exercícios", style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const Center(child: Text("Nenhum exercício na biblioteca.", style: TextStyle(color: Colors.white54)));

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.fitness_center, color: AppColors.primary, size: 20)),
                        title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(data['grupo'] ?? '', style: const TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        onTap: () {
                          Navigator.pop(ctx2);
                          _configurarExercicioImportado(diaKey, data);
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
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _configurarExercicioImportado(String diaKey, Map<String, dynamic> dadosExercicio) {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Configurar: ${dadosExercicio['nome']}", style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildDialogInput(seriesCtrl, "Séries", isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildDialogInput(repsCtrl, "Repetições", isNumber: true)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final novo = WorkoutExercise(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                nome: dadosExercicio['nome'],
                series: seriesCtrl.text,
                repeticoes: repsCtrl.text,
                videoUrl: dadosExercicio['videoUrl'], 
              );
              
              List<WorkoutExercise> lista = _cacheExercicios[diaKey] ?? [];
              lista.add(novo);
              _cacheExercicios[diaKey] = lista;
              
              await _salvarListaDoDia(diaKey);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Adicionar à Ficha", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _salvarComoTemplateDialog(String diaKey) {
    final exercicios = _cacheExercicios[diaKey] ?? [];
    if (exercicios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicione exercícios primeiro!"), backgroundColor: AppColors.error));
      return;
    }

    final nomeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Salvar na Biblioteca", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nomeCtrl,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: "Nome (ex: Ficha A - Hipertrofia)",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              if (nomeCtrl.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('workout_templates').add({
                  'personalId': FirebaseAuth.instance.currentUser!.uid,
                  'nome': nomeCtrl.text.trim(),
                  'exercicios': exercicios.map((e) => e.toMap()).toList(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template salvo na biblioteca!", style: TextStyle(color: Colors.black)), backgroundColor: AppColors.success));
                }
              }
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- CORREÇÃO AQUI (Uso do ctx) ---
  void _importarTemplateDialog(String diaKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx2, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Minha Biblioteca", style: TextStyle(color: AppColors.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('workout_templates')
                    .where('personalId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                  final docs = snapshot.data?.docs ?? [];
                  
                  if (docs.isEmpty) return const Center(child: Text("Você ainda não salvou nenhum template.", style: TextStyle(color: Colors.white54)));

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final List listaEx = data['exercicios'] ?? [];
                      
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.fitness_center, color: AppColors.secondary, size: 20)),
                        title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${listaEx.length} exercícios", style: const TextStyle(color: Colors.white54)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: "Apagar Template",
                          onPressed: () => FirebaseFirestore.instance.collection('workout_templates').doc(docs[index].id).delete(),
                        ),
                        onTap: () async {
                          List<WorkoutExercise> novosExercicios = listaEx.map((e) {
                            final ex = WorkoutExercise.fromMap(e as Map<String, dynamic>);
                            ex.id = DateTime.now().microsecondsSinceEpoch.toString() + ex.nome.hashCode.toString();
                            ex.concluido = false; 
                            return ex;
                          }).toList();

                          List<WorkoutExercise> atuais = _cacheExercicios[diaKey] ?? [];
                          atuais.addAll(novosExercicios);
                          _cacheExercicios[diaKey] = atuais;
                          
                          await _salvarListaDoDia(diaKey);
                          
                          if (mounted) {
                            Navigator.pop(ctx2);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template importado com sucesso!", style: TextStyle(color: Colors.black)), backgroundColor: AppColors.success));
                          }
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
    );
  }
}
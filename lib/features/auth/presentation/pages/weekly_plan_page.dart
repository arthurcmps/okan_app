import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; // Importe suas cores
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

  bool get _souPersonal {
    final meuId = FirebaseAuth.instance.currentUser?.uid;
    return meuId != widget.studentId;
  }

  @override
  void initState() {
    super.initState();
    int diaHoje = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, vsync: this, initialIndex: diaHoje);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Fundo Roxo Escuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white, // Ícone de voltar branco
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
          // Estilo das Abas (Neon/Tribal)
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

              return _buildDiaContent(diaKey, exercicios);
            }).toList(),
          );
        },
      ),
      floatingActionButton: _souPersonal
          ? FloatingActionButton(
              backgroundColor: AppColors.primary, // Terracota para destaque
              onPressed: _adicionarExercicioDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildDiaContent(String diaKey, List<WorkoutExercise> exercicios) {
    if (exercicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 60, color: Colors.white10),
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
            itemCount: exercicios.length,
            itemBuilder: (context, index) {
              final ex = exercicios[index];
              return Card(
                elevation: 4,
                color: AppColors.surface, // Card Escuro
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  
                  // CHECKBOX
                  leading: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: ex.concluido,
                      activeColor: AppColors.secondary, // Neon
                      checkColor: Colors.black,
                      shape: const CircleBorder(),
                      side: const BorderSide(color: Colors.white54),
                      onChanged: (val) {
                        _atualizarStatusExercicio(diaKey, ex, val ?? false);
                      },
                    ),
                  ),
                  
                  // NOME DO EXERCÍCIO
                  title: Text(
                    ex.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ex.concluido ? TextDecoration.lineThrough : null,
                      // AQUI ESTAVA O ERRO: Agora usamos Branco ou Transparente
                      color: ex.concluido ? Colors.white24 : Colors.white,
                    ),
                  ),
                  
                  // SÉRIES E REPETIÇÕES
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Text(
                          "${ex.series} x ${ex.repeticoes}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        
                        // CARGA
                        InkWell(
                          onTap: () => _editarCargaDialog(diaKey, ex),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black26, // Fundo escuro para a carga
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

                  // AÇÕES PERSONAL
                  trailing: _souPersonal
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white54),
                              onPressed: () => _editarExercicioCompletoDialog(diaKey, ex),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _removerExercicio(diaKey, ex),
                            ),
                          ],
                        )
                      : null,
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
                  backgroundColor: AppColors.success, // Verde Sucesso
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

  // --- LÓGICA DE FINALIZAR TREINO ---

  void _confirmarFinalizacao(String diaKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface, // Fundo Escuro
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Treino salvo no histórico! 💪"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
      }
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

  // --- MODAIS DE EDIÇÃO (DARK MODE) ---

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
              });
              _salvarListaDoDia(diaKey);
              Navigator.pop(context);
            },
            child: const Text("Salvar Alterações", style: TextStyle(color: Colors.white)),
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
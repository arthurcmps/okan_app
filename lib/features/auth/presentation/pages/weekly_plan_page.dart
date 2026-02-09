import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/workout_plans_model.dart'; // <--- Certifique-se que o arquivo do Passo 1 existe!

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

  // Cache local para edição rápida
  final Map<String, List<WorkoutExercise>> _cacheExercicios = {};

  bool get _souPersonal {
    final meuId = FirebaseAuth.instance.currentUser?.uid;
    return meuId != widget.studentId;
  }

  @override
  void initState() {
    super.initState();
    // Tenta iniciar na aba do dia de hoje
    int diaHoje = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, vsync: this, initialIndex: diaHoje);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_souPersonal ? "Editar Treino" : "Treino da Semana"),
            Text(widget.studentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _titulosAbas.map((dia) => Tab(text: dia)).toList(),
          labelColor: Colors.blue[800],
          indicatorColor: Colors.blue,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_plans')
            .doc(widget.studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};

          return TabBarView(
            controller: _tabController,
            children: _diasDaSemana.map((diaKey) {
              final listaRaw = data[diaKey] as List<dynamic>? ?? [];
              
              // Converte e guarda no cache
              final exercicios = listaRaw.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>)).toList();
              _cacheExercicios[diaKey] = exercicios;

              return _buildDiaContent(diaKey, exercicios);
            }).toList(),
          );
        },
      ),
      floatingActionButton: _souPersonal
          ? FloatingActionButton(
              onPressed: _adicionarExercicioDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ... (Imports anteriores) ...

  Widget _buildDiaContent(String diaKey, List<WorkoutExercise> exercicios) {
    if (exercicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              _souPersonal ? "Toque no + para adicionar" : "Descanso.", 
              style: TextStyle(color: Colors.grey[500])
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
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  
                  // CHECKBOX
                  leading: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: ex.concluido,
                      activeColor: Colors.green,
                      shape: const CircleBorder(),
                      onChanged: (val) {
                        _atualizarStatusExercicio(diaKey, ex, val ?? false);
                      },
                    ),
                  ),
                  
                  title: Text(
                    ex.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: ex.concluido ? TextDecoration.lineThrough : null,
                      color: ex.concluido ? Colors.grey : Colors.black87,
                    ),
                  ),
                  
                  subtitle: Row(
                    children: [
                      Text("${ex.series}x${ex.repeticoes}"),
                      const SizedBox(width: 12),
                      
                      // CARGA
                      InkWell(
                        onTap: () => _editarCargaDialog(diaKey, ex),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade400)
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monitor_weight_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                ex.carga.isEmpty ? "Carga?" : "${ex.carga}kg",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ex.carga.isEmpty ? Colors.red.shade300 : Colors.black87
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // AÇÕES PERSONAL
                  trailing: _souPersonal
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _editarExercicioCompletoDialog(diaKey, ex),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
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

        // --- BOTÃO DE FINALIZAR TREINO (SÓ PARA O ALUNO) ---
        if (!_souPersonal && exercicios.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text("FINALIZAR TREINO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        title: const Text("Concluir Treino?"),
        content: const Text("Isso vai salvar o histórico de hoje e desmarcar os exercícios para a próxima semana."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _salvarHistoricoEResetar(diaKey);
            },
            child: const Text("Concluir"),
          )
        ],
      ),
    );
  }

  Future<void> _salvarHistoricoEResetar(String diaKey) async {
    // 1. Pega os exercícios atuais do cache
    final exerciciosAtuais = _cacheExercicios[diaKey] ?? [];
    
    // 2. Filtra só os que foram feitos (opcional, mas recomendado salvar tudo para ver o que pulou)
    // Vamos salvar TODOS para ter o registro completo do que estava planejado
    
    try {
      // 3. Salva na coleção 'workout_history'
      await FirebaseFirestore.instance.collection('workout_history').add({
        'studentId': widget.studentId,
        'diaDaSemana': diaKey,
        'dataRealizacao': FieldValue.serverTimestamp(),
        // Salva uma cópia dos exercícios COM as cargas usadas hoje
        'exercicios': exerciciosAtuais.map((e) => e.toMap()).toList(),
      });

      // 4. Reseta os Checkboxes para False (para a semana que vem)
      for (var ex in exerciciosAtuais) {
        ex.concluido = false;
      }
      
      // Atualiza o cache e salva no banco de planejamento
      _cacheExercicios[diaKey] = exerciciosAtuais;
      await _salvarListaDoDia(diaKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Treino salvo no histórico! 💪"), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- LÓGICA DE SALVAMENTO ---

  Future<void> _salvarListaDoDia(String diaKey) async {
    // Correção de Null Safety: Se a lista for nula, usa lista vazia
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

  void _editarCargaDialog(String diaKey, WorkoutExercise ex) {
    final cargaCtrl = TextEditingController(text: ex.carga);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Carga - ${ex.nome}"),
        content: TextField(
          controller: cargaCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Peso (kg)", suffixText: "kg"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() => ex.carga = cargaCtrl.text);
              _salvarListaDoDia(diaKey);
              Navigator.pop(context);
            },
            child: const Text("Salvar"),
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
        title: const Text("Editar Exercício"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome")),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: seriesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Séries"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: repsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Reps"))),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ex.nome = nomeCtrl.text;
                ex.series = seriesCtrl.text;
                ex.repeticoes = repsCtrl.text;
              });
              _salvarListaDoDia(diaKey);
              Navigator.pop(context);
            },
            child: const Text("Salvar Alterações"),
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
        title: const Text("Adicionar Exercício"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome do Exercício")),
            Row(
              children: [
                Expanded(child: TextField(controller: seriesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Séries"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: repsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Repetições"))),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nomeCtrl.text.isNotEmpty) {
                final novo = WorkoutExercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nome: nomeCtrl.text,
                  series: seriesCtrl.text,
                  repeticoes: repsCtrl.text,
                );
                
                final diaAtual = _diasDaSemana[_tabController.index];
                
                // Adiciona na lista local e salva (com proteção de nulo)
                List<WorkoutExercise> lista = _cacheExercicios[diaAtual] ?? [];
                lista.add(novo);
                _cacheExercicios[diaAtual] = lista;
                
                await _salvarListaDoDia(diaAtual);
                
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Adicionar"),
          )
        ],
      ),
    );
  }

  Future<void> _removerExercicio(String diaKey, WorkoutExercise ex) async {
    setState(() {
      // Proteção de nulo ao remover
      if (_cacheExercicios[diaKey] != null) {
        _cacheExercicios[diaKey]!.removeWhere((element) => element.id == ex.id);
      }
    });
    await _salvarListaDoDia(diaKey);
  }
}
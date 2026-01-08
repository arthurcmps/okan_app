import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateWorkoutPage extends StatefulWidget {
  final String? treinoId; // Se vier, é edição
  final Map<String, dynamic>? treinoDados; // Dados para preencher

  const CreateWorkoutPage({
    super.key,
    this.treinoId,
    this.treinoDados,
  });

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeTreinoController = TextEditingController();
  final _grupoMuscularController = TextEditingController();
  final List<Map<String, dynamic>> _exerciciosSelecionados = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Se for edição, preenche os campos
    if (widget.treinoDados != null) {
      _nomeTreinoController.text = widget.treinoDados!['nome'] ?? '';
      _grupoMuscularController.text = widget.treinoDados!['grupoMuscular'] ?? '';
      if (widget.treinoDados!['exercicios'] != null) {
        _exerciciosSelecionados.addAll(
          List<Map<String, dynamic>>.from(widget.treinoDados!['exercicios']),
        );
      }
    }
  }

  Future<void> _salvarTreino() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exerciciosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicione exercícios!")));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final dadosTreino = {
        'nome': _nomeTreinoController.text.trim(),
        'grupoMuscular': _grupoMuscularController.text.trim(),
        'exercicios': _exerciciosSelecionados,
        // Mantém o 'criadoEm' se for edição, ou cria novo se for criação
        'criadoEm': widget.treinoId != null ? widget.treinoDados!['criadoEm'] : FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
        'personalId': user?.uid, // Garante que o dono é mantido
      };

      if (widget.treinoId != null) {
        // --- MODO EDIÇÃO: ATUALIZA ---
        await FirebaseFirestore.instance
            .collection('workouts')
            .doc(widget.treinoId)
            .update(dadosTreino);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino atualizado!")));
        }
      } else {
        // --- MODO CRIAÇÃO: ADICIONA ---
        await FirebaseFirestore.instance.collection('workouts').add(dadosTreino);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino criado!")));
        }
      }

      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _adicionarExercicioModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text("Selecione da Biblioteca", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final ex = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(ex['nome']),
                            subtitle: Text(ex['grupo'] ?? ''),
                            trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
                            onTap: () {
                              Navigator.pop(context);
                              _configurarSeries(ex);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _configurarSeries(Map<String, dynamic> exercicio) {
    final seriesCtrl = TextEditingController(text: "3");
    final repsCtrl = TextEditingController(text: "12");
    final obsCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Configurar ${exercicio['nome']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: seriesCtrl, decoration: const InputDecoration(labelText: "Séries"), keyboardType: TextInputType.number),
            TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: "Repetições"), keyboardType: TextInputType.number),
            TextField(controller: obsCtrl, decoration: const InputDecoration(labelText: "Observação (Opcional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _exerciciosSelecionados.add({
                  'nome': exercicio['nome'],
                  'videoUrl': exercicio['videoUrl'] ?? '',
                  'series': seriesCtrl.text,
                  'repeticoes': repsCtrl.text,
                  'observacao': obsCtrl.text,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.treinoId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Editar Treino" : "Criar Treino")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nomeTreinoController, decoration: const InputDecoration(labelText: "Nome do Treino"), validator: (v) => v!.isEmpty ? "Obrigatório" : null),
              const SizedBox(height: 10),
              TextFormField(controller: _grupoMuscularController, decoration: const InputDecoration(labelText: "Grupo Muscular (Ex: Costas)")),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Exercícios", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_box, size: 30, color: Colors.blue), onPressed: _adicionarExercicioModal),
                ],
              ),
              const Divider(),
              
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _exerciciosSelecionados.removeAt(oldIndex);
                      _exerciciosSelecionados.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < _exerciciosSelecionados.length; i++)
                      ListTile(
                        key: ValueKey("ex_$i${_exerciciosSelecionados[i]['nome']}"), // Chave única
                        tileColor: Colors.grey.shade50,
                        leading: CircleAvatar(child: Text("${i + 1}")),
                        title: Text(_exerciciosSelecionados[i]['nome']),
                        subtitle: Text("${_exerciciosSelecionados[i]['series']}x ${_exerciciosSelecionados[i]['repeticoes']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red), 
                          onPressed: () => setState(() => _exerciciosSelecionados.removeAt(i))
                        ),
                      )
                  ],
                ),
              ),
              
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _salvarTreino, 
                  style: ElevatedButton.styleFrom(backgroundColor: isEditing ? Colors.orange : Colors.blue),
                  child: Text(isEditing ? "ATUALIZAR TREINO" : "SALVAR TREINO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
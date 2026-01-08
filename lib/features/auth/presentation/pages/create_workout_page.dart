import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeTreinoController = TextEditingController();
  final _grupoMuscularController = TextEditingController();
  final List<Map<String, dynamic>> _exerciciosSelecionados = [];
  bool _isLoading = false;

  Future<void> _salvarTreino() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exerciciosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicione exercícios!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('workouts').add({
        'personalId': FirebaseAuth.instance.currentUser?.uid,
        'nome': _nomeTreinoController.text.trim(),
        'grupoMuscular': _grupoMuscularController.text.trim(),
        'exercicios': _exerciciosSelecionados,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino Criado!"), backgroundColor: Colors.green));
      }
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
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text("Selecione um Exercício", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // AQUI ESTÁ O SEGREDO: Buscando de 'exercises'
                    stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum exercício cadastrado na biblioteca."));

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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Configurar ${exercicio['nome']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: seriesCtrl, decoration: const InputDecoration(labelText: "Séries"), keyboardType: TextInputType.number),
            TextField(controller: repsCtrl, decoration: const InputDecoration(labelText: "Repetições"), keyboardType: TextInputType.number),
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
    return Scaffold(
      appBar: AppBar(title: const Text("Criar Treino")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nomeTreinoController, decoration: const InputDecoration(labelText: "Nome do Treino"), validator: (v) => v!.isEmpty ? "Obrigatório" : null),
              const SizedBox(height: 10),
              TextFormField(controller: _grupoMuscularController, decoration: const InputDecoration(labelText: "Grupo Muscular")),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Exercícios", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_box, size: 30, color: Colors.blue), onPressed: _adicionarExercicioModal),
                ],
              ),
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
                        key: ValueKey(i),
                        title: Text(_exerciciosSelecionados[i]['nome']),
                        subtitle: Text("${_exerciciosSelecionados[i]['series']}x ${_exerciciosSelecionados[i]['repeticoes']}"),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _exerciciosSelecionados.removeAt(i))),
                      )
                  ],
                ),
              ),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _salvarTreino, child: const Text("SALVAR TREINO"))),
            ],
          ),
        ),
      ),
    );
  }
}
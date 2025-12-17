import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TreinoDetalhesPage extends StatefulWidget {
  final String nomeTreino;
  final String grupoMuscular;
  final String treinoId;

  const TreinoDetalhesPage({
    super.key,
    required this.nomeTreino,
    required this.grupoMuscular,
    required this.treinoId,
  });

  @override
  State<TreinoDetalhesPage> createState() => _TreinoDetalhesPageState();
}

class _TreinoDetalhesPageState extends State<TreinoDetalhesPage> {
  // Variáveis locais para atualizar o título na tela se editar
  late String _nomeAtual;
  late String _grupoAtual;

  // Controladores para ADICIONAR/EDITAR exercícios
  final TextEditingController _nomeExercicioController = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();

  // Controladores para EDITAR O TREINO
  final TextEditingController _nomeTreinoController = TextEditingController();
  final TextEditingController _grupoTreinoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializa com os dados que vieram da Home
    _nomeAtual = widget.nomeTreino;
    _grupoAtual = widget.grupoMuscular;
  }

  // --- FUNÇÕES DE EXERCÍCIO (Adicionar, Editar, Excluir) ---

  void _mostrarDialogoExercicio({String? docId, String? nomeAtual, String? seriesAtual}) {
    // Se vierem dados, é EDIÇÃO. Se não, é CRIAÇÃO.
    final bool isEditando = docId != null;

    if (isEditando) {
      _nomeExercicioController.text = nomeAtual ?? "";
      _seriesController.text = seriesAtual ?? "";
    } else {
      _nomeExercicioController.clear();
      _seriesController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditando ? "Editar Exercício" : "Novo Exercício"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomeExercicioController,
                decoration: const InputDecoration(labelText: "Nome (ex: Supino)"),
              ),
              TextField(
                controller: _seriesController,
                decoration: const InputDecoration(labelText: "Séries (ex: 4x12)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nomeExercicioController.text.isEmpty) return;

                final collection = FirebaseFirestore.instance
                    .collection('treinos')
                    .doc(widget.treinoId)
                    .collection('exercicios');

                if (isEditando) {
                  // ATUALIZAR
                  await collection.doc(docId).update({
                    'nome': _nomeExercicioController.text,
                    'series': _seriesController.text,
                  });
                } else {
                  // CRIAR NOVO
                  await collection.add({
                    'nome': _nomeExercicioController.text,
                    'series': _seriesController.text,
                    'concluido': false,
                    'ordem': DateTime.now().millisecondsSinceEpoch,
                  });

                  // Incrementa contador no treino pai
                  FirebaseFirestore.instance
                      .collection('treinos')
                      .doc(widget.treinoId)
                      .update({'qtd_exercicios': FieldValue.increment(1)});
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirExercicio(String docId) async {
    await FirebaseFirestore.instance
        .collection('treinos')
        .doc(widget.treinoId)
        .collection('exercicios')
        .doc(docId)
        .delete();

    // Decrementa contador (Opcional)
    FirebaseFirestore.instance
        .collection('treinos')
        .doc(widget.treinoId)
        .update({'qtd_exercicios': FieldValue.increment(-1)});
  }

  // --- FUNÇÕES DE TREINO (Editar, Excluir, Salvar Histórico) ---

  void _editarTreino() {
    _nomeTreinoController.text = _nomeAtual;
    _grupoTreinoController.text = _grupoAtual;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Treino"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeTreinoController,
              decoration: const InputDecoration(labelText: "Nome do Treino"),
            ),
            TextField(
              controller: _grupoTreinoController,
              decoration: const InputDecoration(labelText: "Grupo Muscular"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              // Atualiza no Firebase
              await FirebaseFirestore.instance
                  .collection('treinos')
                  .doc(widget.treinoId)
                  .update({
                'nome': _nomeTreinoController.text,
                'grupo': _grupoTreinoController.text,
              });

              // Atualiza na tela atual visualmente
              setState(() {
                _nomeAtual = _nomeTreinoController.text;
                _grupoAtual = _grupoTreinoController.text;
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirTreino() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Treino?"),
        content: const Text("Isso apagará tudo. Tem certeza?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Excluir", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final exerciciosRef = FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios');
      final snapshots = await exerciciosRef.get();
      for (var doc in snapshots.docs) { batch.delete(doc.reference); }
      await batch.commit();

      await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino excluído!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _salvarHistorico() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Salva no Histórico (Isso já existia)
      await FirebaseFirestore.instance.collection('historico').add({
        'usuarioId': user.uid,
        'treinoNome': _nomeAtual,
        'treinoId': widget.treinoId,
        'data': FieldValue.serverTimestamp(),
      });

      // --- NOVIDADE: RESETAR OS CHECKS ---
      
      // Pega todos os exercícios desse treino
      final snapshot = await FirebaseFirestore.instance
          .collection('treinos')
          .doc(widget.treinoId)
          .collection('exercicios')
          .get();

      // Cria um lote de escrita (Batch) para ser rápido
      final batch = FirebaseFirestore.instance.batch();

      // Para cada exercício, manda atualizar 'concluido' para false
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'concluido': false});
      }

      // Executa todas as atualizações de uma vez
      await batch.commit();

      // -----------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Treino finalizado! Até a próxima. 💪'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomeAtual), // Usa a variável local que pode ser editada
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botão EDITAR TREINO
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar Informações',
            onPressed: _editarTreino,
          ),
          // Botão EXCLUIR TREINO
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir Treino',
            onPressed: _excluirTreino,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Foco de hoje:", style: TextStyle(color: Colors.blue.shade900, fontSize: 14)),
                Text(_grupoAtual, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').orderBy('ordem').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum exercício cadastrado."));

                final exercicios = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: exercicios.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = exercicios[index];
                    final dados = doc.data() as Map<String, dynamic>;
                    final nome = dados['nome']?.toString() ?? 'Sem nome';
                    final series = dados['series']?.toString() ?? '-';
                    final bool feito = dados['concluido'] ?? false;

                    // AQUI MUDOU: Usamos ListTile com Checkbox e PopupMenu
                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 8, right: 8),
                      // Checkbox na esquerda
                      leading: Checkbox(
                        value: feito,
                        activeColor: Colors.blue,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').doc(doc.id).update({'concluido': val});
                        },
                      ),
                      // Textos no meio
                      title: Text(
                        nome,
                        style: TextStyle(fontWeight: FontWeight.bold, decoration: feito ? TextDecoration.lineThrough : null, color: feito ? Colors.grey : Colors.black),
                      ),
                      subtitle: Text(series, style: TextStyle(color: Colors.grey[600])),
                      
                      // Menu de Opções na direita (Três pontinhos)
                      trailing: PopupMenuButton<String>(
                        onSelected: (valor) {
                          if (valor == 'editar') {
                            _mostrarDialogoExercicio(docId: doc.id, nomeAtual: nome, seriesAtual: series);
                          } else if (valor == 'excluir') {
                            _excluirExercicio(doc.id);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'editar',
                            child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Editar')]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'excluir',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarHistorico,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("FINALIZAR TREINO"),
              ),
            ),
          ),
        ],
      ),
      // Botão flutuante para ADICIONAR (chama o diálogo sem parâmetros)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _mostrarDialogoExercicio(),
      ),
    );
  }
}
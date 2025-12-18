import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- Importante para abrir o vídeo

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
  late String _nomeAtual;
  late String _grupoAtual;

  final TextEditingController _nomeExercicioController = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();
  final TextEditingController _nomeTreinoController = TextEditingController();
  final TextEditingController _grupoTreinoController = TextEditingController();

  // Lista local que será preenchida com dados do Firebase
  List<Map<String, dynamic>> _bibliotecaExercicios = [];
  String? _linkVideoSelecionado; // Guarda o link temporariamente ao escolher no Autocomplete

  @override
  void initState() {
    super.initState();
    _nomeAtual = widget.nomeTreino;
    _grupoAtual = widget.grupoMuscular;
    _carregarBiblioteca();
  }

  // Busca os exercícios e links da coleção 'library'
  Future<void> _carregarBiblioteca() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('library').get();
      final lista = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'nome': data['nome'] ?? '',
          'video': data['video'] ?? '',
        };
      }).toList();

      setState(() {
        _bibliotecaExercicios = lista;
      });
    } catch (e) {
      debugPrint("Erro ao carregar biblioteca: $e");
    }
  }

  // Função para abrir o vídeo
  Future<void> _abrirVideo(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o vídeo.')));
      }
    }
  }

  void _mostrarDialogoExercicio({String? docId, String? nomeAtual, String? seriesAtual}) {
    final bool isEditando = docId != null;
    _linkVideoSelecionado = null; // Reseta o link

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
              // --- AUTOCOMPLETE INTELIGENTE ---
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable.empty();
                  return _bibliotecaExercicios.where((Map<String, dynamic> option) {
                    return option['nome'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                // O que aparece na lista de sugestões
                displayStringForOption: (Map<String, dynamic> option) => option['nome'],
                
                onSelected: (Map<String, dynamic> selection) {
                  _nomeExercicioController.text = selection['nome'];
                  _linkVideoSelecionado = selection['video']; // CAPTURA O LINK AQUI
                },
                
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (textEditingController.text.isEmpty && _nomeExercicioController.text.isNotEmpty) {
                    textEditingController.text = _nomeExercicioController.text;
                  }
                  textEditingController.addListener(() {
                     _nomeExercicioController.text = textEditingController.text;
                  });
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Nome do Exercício",
                      hintText: "Digite para buscar (ex: Supino)",
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _seriesController,
                decoration: const InputDecoration(labelText: "Séries (ex: 4x12)", prefixIcon: Icon(Icons.repeat)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (_nomeExercicioController.text.isEmpty) return;

                final collection = FirebaseFirestore.instance
                    .collection('treinos')
                    .doc(widget.treinoId)
                    .collection('exercicios');

                if (isEditando) {
                  await collection.doc(docId).update({
                    'nome': _nomeExercicioController.text,
                    'series': _seriesController.text,
                    // Nota: Na edição simples, não estamos atualizando o link para não complicar,
                    // mas poderia ser feito buscando na lista novamente.
                  });
                } else {
                  // Se o usuário digitou um nome que NÃO está na lista, o link será null.
                  // Se ele clicou na sugestão, _linkVideoSelecionado terá o URL.
                  
                  // Segurança extra: Se o link for nulo, tenta achar na lista pelo nome digitado
                  if (_linkVideoSelecionado == null) {
                     final match = _bibliotecaExercicios.firstWhere(
                       (e) => e['nome'].toLowerCase() == _nomeExercicioController.text.toLowerCase(),
                       orElse: () => {},
                     );
                     if (match.isNotEmpty) _linkVideoSelecionado = match['video'];
                  }

                  await collection.add({
                    'nome': _nomeExercicioController.text,
                    'series': _seriesController.text,
                    'concluido': false,
                    'ordem': DateTime.now().millisecondsSinceEpoch,
                    'videoUrl': _linkVideoSelecionado, // SALVA O LINK NO EXERCÍCIO DO TREINO
                  });

                  FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).update({'qtd_exercicios': FieldValue.increment(1)});
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

  // --- MÉTODOS DE MANUTENÇÃO (Iguais) ---
  Future<void> _excluirExercicio(String docId) async {
    await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').doc(docId).delete();
    FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).update({'qtd_exercicios': FieldValue.increment(-1)});
  }

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
            TextField(controller: _nomeTreinoController, decoration: const InputDecoration(labelText: "Nome")),
            TextField(controller: _grupoTreinoController, decoration: const InputDecoration(labelText: "Grupo")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).update({
                'nome': _nomeTreinoController.text,
                'grupo': _grupoTreinoController.text,
              });
              setState(() { _nomeAtual = _nomeTreinoController.text; _grupoAtual = _grupoTreinoController.text; });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirTreino() async {
    final confirmar = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text("Excluir?"), content: const Text("Apagar tudo?"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Não")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sim", style: TextStyle(color: Colors.red)))]));
    if (confirmar != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final exerciciosRef = FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios');
      final snapshots = await exerciciosRef.get();
      for (var doc in snapshots.docs) { batch.delete(doc.reference); }
      await batch.commit();
      await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); }
  }

  Future<void> _salvarHistorico() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('historico').add({
      'usuarioId': user.uid, 'treinoNome': _nomeAtual, 'treinoId': widget.treinoId, 'data': FieldValue.serverTimestamp(),
    });
    final snapshot = await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) { batch.update(doc.reference, {'concluido': false}); }
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino finalizado!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomeAtual),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _editarTreino), IconButton(icon: const Icon(Icons.delete_outline), onPressed: _excluirTreino)],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), width: double.infinity, color: Colors.blue.shade50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Foco:", style: TextStyle(color: Colors.blue.shade900)), Text(_grupoAtual, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').orderBy('ordem').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum exercício."));
                final exercicios = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: exercicios.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = exercicios[index];
                    final dados = doc.data() as Map<String, dynamic>;
                    final nome = dados['nome'] ?? 'Sem nome';
                    final series = dados['series'] ?? '-';
                    final bool feito = dados['concluido'] ?? false;
                    final String? videoUrl = dados['videoUrl']; // Ler o link salvo

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Checkbox(
                        value: feito, activeColor: Colors.blue,
                        onChanged: (val) => FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').doc(doc.id).update({'concluido': val}),
                      ),
                      title: Text(nome, style: TextStyle(fontWeight: FontWeight.bold, decoration: feito ? TextDecoration.lineThrough : null, color: feito ? Colors.grey : Colors.black)),
                      subtitle: Text(series, style: TextStyle(color: Colors.grey[600])),
                      
                      // --- BOTÃO DE VÍDEO NOVO ---
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (videoUrl != null && videoUrl.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
                              tooltip: 'Ver execução',
                              onPressed: () => _abrirVideo(videoUrl),
                            ),
                          
                          PopupMenuButton<String>(
                            onSelected: (v) => v == 'excluir' ? _excluirExercicio(doc.id) : _mostrarDialogoExercicio(docId: doc.id, nomeAtual: nome, seriesAtual: series),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'editar', child: Text("Editar")),
                              const PopupMenuItem(value: 'excluir', child: Text("Excluir", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _salvarHistorico, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("FINALIZAR TREINO")))),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.blue, child: const Icon(Icons.add, color: Colors.white), onPressed: () => _mostrarDialogoExercicio()),
    );
  }
}
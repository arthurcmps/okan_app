import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/time_service.dart';

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
  final TextEditingController _cargaController = TextEditingController(); // <--- NOVO
  final TextEditingController _nomeTreinoController = TextEditingController();
  final TextEditingController _grupoTreinoController = TextEditingController();

  List<Map<String, dynamic>> _bibliotecaExercicios = [];
  String? _linkVideoSelecionado;

  @override
  void initState() {
    super.initState();
    _nomeAtual = widget.nomeTreino;
    _grupoAtual = widget.grupoMuscular;
    _carregarBiblioteca();
  }

  // --- LÓGICA DO CRONÔMETRO GLOBAL ---
  void _mostrarSeletorTempo() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Iniciar Descanso Global", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _botaoTempo(30),
                  _botaoTempo(45),
                  _botaoTempo(60),
                  _botaoTempo(90),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _botaoTempo(int seg) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(20), backgroundColor: Colors.blue.shade50),
      onPressed: () {
        Navigator.pop(context);
        TimerService.instance.start(seg); 
      },
      child: Text("${seg}s", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Future<void> _carregarBiblioteca() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('library').get();
      final lista = snapshot.docs.map((doc) {
        final data = doc.data();
        return { 'nome': data['nome'] ?? '', 'video': data['video'] ?? '' };
      }).toList();
      setState(() { _bibliotecaExercicios = lista; });
    } catch (e) { debugPrint("Erro biblioteca: $e"); }
  }

  Future<void> _abrirVideo(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir vídeo.')));
    }
  }

  void _mostrarDialogoExercicio({String? docId, String? nomeAtual, String? seriesAtual, String? cargaAtual}) {
    final bool isEditando = docId != null;
    _linkVideoSelecionado = null;

    if (isEditando) {
      _nomeExercicioController.text = nomeAtual ?? "";
      _seriesController.text = seriesAtual ?? "";
      _cargaController.text = cargaAtual ?? ""; // <--- Carrega a carga existente
    } else {
      _nomeExercicioController.clear();
      _seriesController.clear();
      _cargaController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditando ? "Editar" : "Novo Exercício"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. AUTOCOMPLETE NOME
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable.empty();
                  return _bibliotecaExercicios.where((Map<String, dynamic> option) {
                    return option['nome'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                displayStringForOption: (Map<String, dynamic> option) => option['nome'],
                onSelected: (Map<String, dynamic> selection) {
                  _nomeExercicioController.text = selection['nome'];
                  _linkVideoSelecionado = selection['video'];
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (textEditingController.text.isEmpty && _nomeExercicioController.text.isNotEmpty) {
                    textEditingController.text = _nomeExercicioController.text;
                  }
                  textEditingController.addListener(() { _nomeExercicioController.text = textEditingController.text; });
                  return TextField(controller: textEditingController, focusNode: focusNode, decoration: const InputDecoration(labelText: "Nome do Exercício", prefixIcon: Icon(Icons.search)));
                },
              ),
              const SizedBox(height: 16),
              
              // 2. LINHA COM SÉRIES E CARGA
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seriesController, 
                      decoration: const InputDecoration(labelText: "Séries (4x12)", prefixIcon: Icon(Icons.repeat))
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cargaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Carga (kg)", prefixIcon: Icon(Icons.monitor_weight_outlined)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (_nomeExercicioController.text.isEmpty) return;
                
                final collection = FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios');
                
                // Dados a salvar
                final dadosParaSalvar = {
                  'nome': _nomeExercicioController.text,
                  'series': _seriesController.text,
                  'carga': _cargaController.text, // <--- SALVA A CARGA
                };

                if (isEditando) {
                  await collection.doc(docId).update(dadosParaSalvar);
                } else {
                  if (_linkVideoSelecionado == null) {
                     final match = _bibliotecaExercicios.firstWhere((e) => e['nome'].toLowerCase() == _nomeExercicioController.text.toLowerCase(), orElse: () => {});
                     if (match.isNotEmpty) _linkVideoSelecionado = match['video'];
                  }
                  
                  await collection.add({
                    ...dadosParaSalvar,
                    'concluido': false,
                    'ordem': DateTime.now().millisecondsSinceEpoch,
                    'videoUrl': _linkVideoSelecionado,
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

  // --- Manutenção ---
  Future<void> _excluirExercicio(String docId) async {
    await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').doc(docId).delete();
    FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).update({'qtd_exercicios': FieldValue.increment(-1)});
  }

  void _editarTreino() {
     _nomeTreinoController.text = _nomeAtual; _grupoTreinoController.text = _grupoAtual;
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Editar Treino"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _nomeTreinoController, decoration: const InputDecoration(labelText: "Nome")), TextField(controller: _grupoTreinoController, decoration: const InputDecoration(labelText: "Grupo"))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).update({'nome': _nomeTreinoController.text, 'grupo': _grupoTreinoController.text}); setState(() { _nomeAtual = _nomeTreinoController.text; _grupoAtual = _grupoTreinoController.text; }); if (context.mounted) Navigator.pop(context); }, child: const Text("Salvar"))]));
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
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    await FirebaseFirestore.instance.collection('historico').add({'usuarioId': user.uid, 'treinoNome': _nomeAtual, 'treinoId': widget.treinoId, 'data': FieldValue.serverTimestamp()});
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
        actions: [
          IconButton(icon: const Icon(Icons.timer), tooltip: 'Descanso', onPressed: _mostrarSeletorTempo), 
          IconButton(icon: const Icon(Icons.edit), onPressed: _editarTreino),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _excluirTreino),
        ],
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
                    final carga = dados['carga'] ?? '-'; // <--- LÊ A CARGA
                    final bool feito = dados['concluido'] ?? false;
                    final String? videoUrl = dados['videoUrl'];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Checkbox(value: feito, activeColor: Colors.blue, onChanged: (val) => FirebaseFirestore.instance.collection('treinos').doc(widget.treinoId).collection('exercicios').doc(doc.id).update({'concluido': val})),
                      
                      title: Text(nome, style: TextStyle(fontWeight: FontWeight.bold, decoration: feito ? TextDecoration.lineThrough : null, color: feito ? Colors.grey : Colors.black)),
                      
                      // EXIBIÇÃO DA CARGA AQUI
                      subtitle: Row(
                        children: [
                          Text(series, style: TextStyle(color: Colors.grey[600])),
                          if (carga != '-' && carga != '') ...[
                            const SizedBox(width: 8),
                            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            const Icon(Icons.monitor_weight_outlined, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text("$carga kg", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ]
                        ],
                      ),
                      
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (videoUrl != null && videoUrl.isNotEmpty) IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 30), tooltip: 'Ver execução', onPressed: () => _abrirVideo(videoUrl)),
                          PopupMenuButton<String>(
                            // Passa a cargaAtual para o dialogo
                            onSelected: (v) => v == 'excluir' ? _excluirExercicio(doc.id) : _mostrarDialogoExercicio(docId: doc.id, nomeAtual: nome, seriesAtual: series, cargaAtual: carga),
                            itemBuilder: (context) => [const PopupMenuItem(value: 'editar', child: Text("Editar")), const PopupMenuItem(value: 'excluir', child: Text("Excluir", style: TextStyle(color: Colors.red)))],
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/universal_video_player.dart'; // Seu player de vídeo

class TrainPage extends StatefulWidget {
  final String workoutId; // Recebe o ID do treino para carregar

  const TrainPage({super.key, required this.workoutId});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  // Mapa para controlar os Checkboxes (quais exercícios já fez)
  final Map<int, bool> _concluidos = {};

  void _finalizarTreino(String nomeTreino) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Salva no Histórico
    await FirebaseFirestore.instance.collection('historico').add({
      'usuarioId': user.uid,
      'treinoId': widget.workoutId,
      'treinoNome': nomeTreino,
      'data': FieldValue.serverTimestamp(),
      'exerciciosConcluidos': _concluidos.length, // Opcional: Salvar quantos fez
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino Concluído! Parabéns! 🔥"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  void _abrirVideo(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: UniversalVideoPlayer(videoUrl: url)),
            Positioned(
              top: 20, right: 20,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hora do Treino 🔥")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('workouts').doc(widget.workoutId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Treino não encontrado ou excluído."));
          }

          final dados = snapshot.data!.data() as Map<String, dynamic>;
          final nomeTreino = dados['nome'] ?? 'Treino';
          final listaExercicios = List<Map<String, dynamic>>.from(dados['exercicios'] ?? []);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(nomeTreino, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: listaExercicios.length,
                  itemBuilder: (context, index) {
                    final ex = listaExercicios[index];
                    final isDone = _concluidos[index] ?? false;

                    return Card(
                      color: isDone ? Colors.green.shade50 : Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isDone,
                                  onChanged: (val) => setState(() => _concluidos[index] = val!),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ex['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null)),
                                      Text("${ex['series']} Séries x ${ex['repeticoes']} Reps", style: const TextStyle(color: Colors.blueGrey)),
                                      if (ex['observacao'] != null && ex['observacao'].isNotEmpty)
                                        Text("Obs: ${ex['observacao']}", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange.shade800, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (ex['videoUrl'] != null && ex['videoUrl'].isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 32),
                                    onPressed: () => _abrirVideo(ex['videoUrl']),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => _finalizarTreino(nomeTreino),
                    child: const Text("CONCLUIR TREINO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/universal_video_player.dart';
import '../../../../core/services/time_service.dart';

class TrainPage extends StatefulWidget {
  final String workoutId;

  const TrainPage({super.key, required this.workoutId});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  final Map<int, bool> _concluidos = {};
  final Map<int, String> _cargas = {};

  void _finalizarTreino(String nomeTreino, List<dynamic> exerciciosOriginais) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> detalheExercicios = [];
    
    for (int i = 0; i < exerciciosOriginais.length; i++) {
      if (_concluidos[i] == true) {
        detalheExercicios.add({
          'nome': exerciciosOriginais[i]['nome'],
          'carga': _cargas[i] ?? '0',
          'series': exerciciosOriginais[i]['series'],
          'repeticoes': exerciciosOriginais[i]['repeticoes'],
        });
      }
    }

    await FirebaseFirestore.instance.collection('historico').add({
      'usuarioId': user.uid,
      'treinoId': widget.workoutId,
      'treinoNome': nomeTreino,
      'data': FieldValue.serverTimestamp(),
      'exerciciosConcluidos': _concluidos.length,
      'detalhes': detalheExercicios,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Treino Concluído! Parabéns! 🔥"), 
        backgroundColor: Colors.green
      ));
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

  // --- NOVA FUNÇÃO: INICIAR DESCANSO MANUALMENTE ---
  void _iniciarDescansoManual() {
    // Inicia 60 segundos (pode ajustar esse valor se quiser)
    TimerService.instance.start(60);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Descanso iniciado: 60s ⏱️"),
      duration: Duration(seconds: 2),
      backgroundColor: Colors.blueGrey,
    ));
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
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                color: Colors.blue.withOpacity(0.1),
                child: Column(
                  children: [
                    Text(nomeTreino.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    Text("${listaExercicios.length} exercícios", style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: listaExercicios.length,
                  itemBuilder: (context, index) {
                    final ex = listaExercicios[index];
                    final isDone = _concluidos[index] ?? false;

                    return Card(
                      color: isDone ? Colors.green.shade50 : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isDone ? BorderSide(color: Colors.green.shade200) : BorderSide.none),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center, // Alinhamento centralizado
                              children: [
                                // 1. CHECKBOX (SÓ MARCA)
                                Transform.scale(
                                  scale: 1.3,
                                  child: Checkbox(
                                    value: isDone,
                                    activeColor: Colors.green,
                                    shape: const CircleBorder(),
                                    onChanged: (val) {
                                      setState(() => _concluidos[index] = val!);
                                      // REMOVIDO: O timer automático que causava erro
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // 2. TEXTOS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ex['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : Colors.black87)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                            child: Text("${ex['series']} x ${ex['repeticoes']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ),
                                          const SizedBox(width: 8),
                                          if (ex['observacao'] != null && ex['observacao'].isNotEmpty)
                                            Expanded(child: Text(ex['observacao'], style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange.shade800, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 3. BOTÃO DE TIMER MANUAL (NOVO)
                                IconButton(
                                  icon: const Icon(Icons.timer_outlined, color: Colors.blueGrey, size: 28),
                                  tooltip: "Iniciar Descanso (60s)",
                                  onPressed: _iniciarDescansoManual, // Chama a função manual
                                ),

                                // 4. BOTÃO DE VÍDEO
                                if (ex['videoUrl'] != null && ex['videoUrl'].isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                                    onPressed: () => _abrirVideo(ex['videoUrl']),
                                  ),
                              ],
                            ),
                            
                            const Divider(),
                            
                            // INPUT DE CARGA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text("Carga usada:", style: TextStyle(color: Colors.grey)),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: "kg",
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    onChanged: (val) {
                                      _cargas[index] = val;
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // BOTÃO CONCLUIR
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _finalizarTreino(nomeTreino, listaExercicios),
                    child: const Text("CONCLUIR TREINO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
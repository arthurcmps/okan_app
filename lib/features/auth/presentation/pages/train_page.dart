import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/universal_video_player.dart';
import '../../../../core/services/time_service.dart';

// Importe suas cores. Se der erro, apague e digite "AppColors" para o VS Code sugerir
import '../../../../core/theme/app_colors.dart';

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
        content: Text("Treino Salvo! 🔥", style: TextStyle(color: Colors.black)), 
        backgroundColor: AppColors.secondary,
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
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white), 
                onPressed: () => Navigator.pop(context)
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _iniciarDescansoManual() {
    print("Iniciando descanso..."); // Log para debug
    TimerService.instance.start(60);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Descanso: 60s ⏱️"),
      duration: Duration(seconds: 1),
      backgroundColor: AppColors.surface,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Hora do Treino 🔥"), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('workouts').doc(widget.workoutId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Treino não encontrado.", style: TextStyle(color: AppColors.textSub)));
          }

          final dados = snapshot.data!.data() as Map<String, dynamic>;
          final nomeTreino = dados['nome'] ?? 'Treino';
          final listaExercicios = List<Map<String, dynamic>>.from(dados['exercicios'] ?? []);

          return Column(
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Column(
                  children: [
                    Text(
                      nomeTreino.toUpperCase(), 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.secondary)
                    ),
                    Text("${listaExercicios.length} exercícios", style: const TextStyle(color: AppColors.textSub)),
                  ],
                ),
              ),
              
              // LISTA
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 10),
                  itemCount: listaExercicios.length,
                  itemBuilder: (context, index) {
                    final ex = listaExercicios[index];
                    final isDone = _concluidos[index] ?? false;

                    return Card(
                      color: isDone ? const Color(0xFF1B3B28) : AppColors.surface,
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), 
                        side: isDone 
                            ? const BorderSide(color: AppColors.secondary, width: 1) 
                            : BorderSide(color: Colors.white.withOpacity(0.05))
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0), // Padding interno reduzido
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // CHECKBOX
                                Transform.scale(
                                  scale: 1.2,
                                  child: Checkbox(
                                    value: isDone,
                                    activeColor: AppColors.secondary,
                                    checkColor: AppColors.background,
                                    shape: const CircleBorder(),
                                    side: const BorderSide(color: AppColors.textSub, width: 2),
                                    onChanged: (val) {
                                      setState(() => _concluidos[index] = val!);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // TEXTO + REPS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex['nome'], 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 16, 
                                          decoration: isDone ? TextDecoration.lineThrough : null, 
                                          color: isDone ? AppColors.textSub.withOpacity(0.5) : AppColors.textMain
                                        )
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(
                                          "${ex['series']} x ${ex['repeticoes']}", 
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // --- BOTÃO CRONÔMETRO (Obrigatório aparecer) ---
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.timer, color: AppColors.secondary, size: 28),
                                    onPressed: _iniciarDescansoManual,
                                    tooltip: "Cronômetro",
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(), // Remove restrições de tamanho
                                  ),
                                ),

                                // BOTÃO VÍDEO
                                if (ex['videoUrl'] != null && ex['videoUrl'].isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 28),
                                    onPressed: () => _abrirVideo(ex['videoUrl']),
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white10),
                            ),
                            
                            // INPUT CARGA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text("Carga:", style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  height: 35,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: "kg",
                                      hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.3)),
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      filled: true,
                                      fillColor: Colors.black26,
                                      suffixText: "kg",
                                      suffixStyle: const TextStyle(fontSize: 10, color: AppColors.textSub),
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
              
              // CONCLUIR
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                color: AppColors.surface,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _finalizarTreino(nomeTreino, listaExercicios),
                  child: const Text("CONCLUIR TREINO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
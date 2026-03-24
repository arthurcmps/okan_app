import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';

class TrainPage extends StatefulWidget {
  final String workoutId; // É o dia da semana (ex: 'segunda')

  const TrainPage({super.key, required this.workoutId});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  final Map<int, bool> _concluidos = {};
  final Map<int, String> _cargas = {};

  // NOVO: Pergunta o feedback antes de finalizar!
  void _pedirFeedbackEFinalizar(String nomeTreino, List<dynamic> exerciciosOriginais) {
    final TextEditingController feedbackCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Treino Concluído! 🎉", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Deixe um feedback para o seu personal (Opcional):", 
              style: TextStyle(color: Colors.white70, fontSize: 13)
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Senti facilidade, ou dor no ombro...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              Navigator.pop(ctx);
              _finalizarTreino(nomeTreino, exerciciosOriginais, feedbackCtrl.text.trim());
            },
            child: const Text("Salvar Histórico", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _finalizarTreino(String nomeTreino, List<dynamic> exerciciosOriginais, String feedbackTexto) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> detalheExercicios = [];
    
    for (int i = 0; i < exerciciosOriginais.length; i++) {
      detalheExercicios.add({
        'nome': exerciciosOriginais[i]['nome'],
        'carga': _cargas[i] ?? exerciciosOriginais[i]['carga'] ?? '',
        'series': exerciciosOriginais[i]['series'],
        'repeticoes': exerciciosOriginais[i]['repeticoes'],
        'concluido': _concluidos[i] == true,
        'id': exerciciosOriginais[i]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }

    try {
      // SALVA NO HISTÓRICO COM O FEEDBACK EMBUTIDO!
      await FirebaseFirestore.instance.collection('workout_history').add({
        'studentId': user.uid,
        'diaDaSemana': widget.workoutId,
        'dataRealizacao': FieldValue.serverTimestamp(),
        'exercicios': detalheExercicios,
        'feedback': feedbackTexto, 
      });

      // Desmarca os exercícios na ficha original para a próxima semana
      final docRef = FirebaseFirestore.instance.collection('workout_plans').doc(user.uid);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        List<dynamic> diaAtualizado = List.from(snapshot.data()![widget.workoutId] ?? []);
        for (var ex in diaAtualizado) {
          if (ex is Map<String, dynamic>) {
            ex['concluido'] = false;
          }
        }
        await docRef.update({widget.workoutId: diaAtualizado});
      }

      if (mounted) {
        Navigator.pop(context); // Volta pra tela anterior
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino finalizado e salvo no histórico!"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Treino - ${widget.workoutId.toUpperCase()}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('workout_plans').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
          
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final listaExercicios = data[widget.workoutId] as List<dynamic>? ?? [];

          if (listaExercicios.isEmpty) {
            return const Center(child: Text("Você não tem exercícios para hoje.", style: TextStyle(color: Colors.white54)));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: listaExercicios.length,
                  itemBuilder: (context, index) {
                    final ex = listaExercicios[index];
                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _concluidos[index] ?? false,
                                  activeColor: AppColors.secondary,
                                  checkColor: Colors.black,
                                  onChanged: (val) => setState(() => _concluidos[index] = val ?? false),
                                ),
                                Expanded(child: Text(ex['nome'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text("${ex['series']}x ${ex['repeticoes']}", style: const TextStyle(color: Colors.white70)),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: "Carga",
                                      hintText: ex['carga'] ?? '',
                                      filled: true,
                                      fillColor: Colors.black26,
                                      suffixText: "kg",
                                      suffixStyle: const TextStyle(fontSize: 10, color: AppColors.textSub),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    onChanged: (val) => _cargas[index] = val,
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
              
              // BOTÃO CONCLUIR QUE CHAMA O NOVO DIÁLOGO DE FEEDBACK
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                color: AppColors.surface,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.black),
                  label: const Text("FINALIZAR TREINO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () => _pedirFeedbackEFinalizar(widget.workoutId, listaExercicios),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
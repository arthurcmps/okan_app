import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/models/workout_history_model.dart';
import '../../data/models/workout_plans_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'evolution_charts_page.dart'; 

class WorkoutHistoryPage extends StatelessWidget {
  final String studentId;
  final String studentName; 

  const WorkoutHistoryPage({
    super.key, 
    required this.studentId,
    required this.studentName, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Histórico de Treinos", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvolutionChartsPage(
                      studentId: studentId,
                      studentName: studentName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.insights, color: AppColors.primary),
              label: const Text("Gráficos", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_history')
            .where('studentId', isEqualTo: studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum treino finalizado ainda.", style: TextStyle(color: Colors.white54)));
          }

          final historyList = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final model = WorkoutHistory.fromMap(doc.id, data);
            
            return {
              'history': model,
              'feedback': data['feedback'] as String? ?? ''
            };
          }).toList();

          historyList.sort((a, b) => (b['history'] as WorkoutHistory).dataRealizacao.compareTo((a['history'] as WorkoutHistory).dataRealizacao));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final item = historyList[index];
              final WorkoutHistory history = item['history'] as WorkoutHistory;
              final String feedback = item['feedback'] as String;
              
              final List<WorkoutExercise> exercicios = history.exercicios.cast<WorkoutExercise>();
              
              final dateStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(history.dataRealizacao);
              final diaNome = history.diaDaSemana.toUpperCase();

              final concluidosCount = exercicios.where((e) => e.concluido).length;

              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: AppColors.primary,
                    collapsedIconColor: Colors.white54,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.success.withOpacity(0.2),
                      child: const Icon(Icons.check, color: AppColors.success),
                    ),
                    title: Text(
                      "$diaNome - $dateStr", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)
                    ),
                    subtitle: Text(
                      "$concluidosCount/${exercicios.length} exercícios concluídos",
                      style: const TextStyle(color: Colors.white54, fontSize: 12)
                    ),
                    children: [
                      ...exercicios.map((ex) => _buildExerciseRow(ex)),
                      
                      if (feedback.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.chat_bubble_outline, color: AppColors.secondary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Feedback do Aluno:", 
                                      style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      feedback, 
                                      style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 14)
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExerciseRow(WorkoutExercise ex) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(
        ex.concluido ? Icons.check_circle : Icons.cancel,
        color: ex.concluido ? AppColors.success : Colors.redAccent.withOpacity(0.5),
        size: 18,
      ),
      title: Text(
        ex.nome,
        style: TextStyle(
          color: ex.concluido ? Colors.white : Colors.white54,
          decoration: ex.concluido ? null : TextDecoration.lineThrough,
        ),
      ),
      trailing: Text(
        ex.carga.isEmpty ? "" : "${ex.carga}kg", 
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary),
      ),
    );
  }
}
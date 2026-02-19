import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/models/workout_history_model.dart';
import '../../data/models/workout_plans_model.dart';

// --- IMPORT DAS CORES E DA NOVA TELA DE GRÁFICOS ---
import '../../../../core/theme/app_colors.dart';
import 'evolution_charts_page.dart'; // Ajuste o caminho se necessário

class WorkoutHistoryPage extends StatelessWidget {
  final String studentId;
  final String studentName; // <-- Adicionado para passar para os gráficos

  const WorkoutHistoryPage({
    super.key, 
    required this.studentId,
    required this.studentName, // <-- Exigindo o nome agora
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Fundo do tema
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Histórico de Treinos", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // --- BOTÃO PARA ABRIR OS GRÁFICOS SANKOFA ---
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
            // Se você criar o índice no Firebase, pode descomentar a linha abaixo:
            // .orderBy('dataRealizacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum treino finalizado ainda.", style: TextStyle(color: Colors.white54)));
          }

          // Pega a lista
          final historyList = snapshot.data!.docs.map((doc) {
            return WorkoutHistory.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          // Se o orderBy do Firebase estiver comentado, ordenamos manualmente aqui pelo Dart
          historyList.sort((a, b) => b.dataRealizacao.compareTo(a.dataRealizacao));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];
              
              final List<WorkoutExercise> exercicios = history.exercicios.cast<WorkoutExercise>();
              
              final dateStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(history.dataRealizacao);
              final diaNome = history.diaDaSemana.toUpperCase();

              final concluidosCount = exercicios.where((e) => e.concluido).length;

              // Estilização Cyber-Sankofa
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                child: Theme(
                  // Remove as linhas feias do ExpansionTile padrão
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
                    children: exercicios.map((ex) => _buildExerciseRow(ex)).toList(),
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
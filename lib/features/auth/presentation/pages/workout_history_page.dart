import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/models/workout_history_model.dart';
import '../../data/models/workout_plans_model.dart';

class WorkoutHistoryPage extends StatelessWidget {
  final String studentId;

  const WorkoutHistoryPage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Histórico de Treinos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_history')
            .where('studentId', isEqualTo: studentId)
            .orderBy('dataRealizacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum treino finalizado ainda."));
          }

          final historyList = snapshot.data!.docs.map((doc) {
            return WorkoutHistory.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];
              
              // --- CORREÇÃO AQUI ---
              // Forçamos o Dart a entender que isso é uma lista de WorkoutExercise
              final List<WorkoutExercise> exercicios = history.exercicios.cast<WorkoutExercise>();
              
              final dateStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(history.dataRealizacao);
              final diaNome = history.diaDaSemana.toUpperCase();

              // Calcula quantos foram concluídos
              final concluidosCount = exercicios.where((e) => e.concluido).length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.check, color: Colors.blue),
                  ),
                  title: Text("$diaNome - $dateStr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("$concluidosCount/${exercicios.length} concluídos"),
                  // Agora passamos a lista 'exercicios' tipada corretamente
                  children: exercicios.map((ex) => _buildExerciseRow(ex)).toList(),
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
        color: ex.concluido ? Colors.green : Colors.grey,
        size: 18,
      ),
      title: Text(ex.nome),
      trailing: Text(
        "${ex.carga}kg", // Se carga for vazia, mostra só "kg" ou nada, conforme sua preferência
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
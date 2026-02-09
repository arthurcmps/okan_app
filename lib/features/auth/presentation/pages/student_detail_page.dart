import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importações dos seus componentes
import '../../../../core/widgets/user_avatar.dart';
import 'chat_page.dart';
import 'weekly_plan_page.dart'; 
import 'workout_history_page.dart'; // <--- IMPORTANTE: Nova importação

class StudentDetailPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Perfil do Aluno"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- CABEÇALHO ---
            Center(
              child: Column(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
                    builder: (context, snapshot) {
                      String? photoUrl;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        photoUrl = data['photoUrl'];
                      }
                      return UserAvatar(
                        photoUrl: photoUrl,
                        name: studentName,
                        radius: 50,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(studentEmail, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Text("ATIVO", style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- AÇÕES RÁPIDAS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                      label: const Text("Mensagem"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(otherUserId: studentId, otherUserName: studentName),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.block, color: Colors.red),
                      label: const Text("Desvincular"),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Use a tela de lista para remover.")));
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- MENU DE GESTÃO ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  // PLANEJAR TREINO
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_calendar, color: Colors.blue),
                    ),
                    title: const Text("Planejar Treino Semanal", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Defina os exercícios de Seg a Dom"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WeeklyPlanPage(
                            studentId: studentId, 
                            studentName: studentName
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const Divider(height: 1, indent: 70),

                  // HISTÓRICO DE TREINOS (Botão Novo)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.history, color: Colors.orange),
                    ),
                    title: const Text("Histórico de Treinos"),
                    subtitle: const Text("Veja o que foi concluído"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutHistoryPage(studentId: studentId), // Passa o ID deste aluno
                        ),
                      );
                    },
                  ),

                  const Divider(height: 1, indent: 70),

                  // DADOS FÍSICOS
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.monitor_weight_outlined, color: Colors.purple),
                    ),
                    title: const Text("Dados Físicos"),
                    subtitle: const Text("Peso, altura e bioimpedância"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      _mostrarDadosFisicos(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDadosFisicos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!.data() as Map<String, dynamic>;
            
            return Container(
              padding: const EdgeInsets.all(24),
              height: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Dados Físicos Atuais", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(Icons.monitor_weight, "${data['peso'] ?? '--'} kg", "Peso"),
                      _buildInfoItem(Icons.height, "${data['altura'] ?? '--'} cm", "Altura"),
                      _buildInfoItem(Icons.cake, "25", "Idade"), 
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blueGrey),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
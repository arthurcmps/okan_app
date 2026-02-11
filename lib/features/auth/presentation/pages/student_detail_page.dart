import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS ---
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart'; // Importe suas cores
import 'chat_page.dart';
import 'weekly_plan_page.dart'; 
import 'workout_history_page.dart';
import 'anamnese_tab.dart'; // <--- CRIAR ESSE ARQUIVO (Código que te passei antes)
import 'assessments_tab.dart'; // <--- CRIAR ESSE ARQUIVO (Código que te passei antes)

class StudentDetailPage extends StatefulWidget {
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
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Fundo Roxo Okan
      appBar: AppBar(
        title: const Text("Perfil do Aluno"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Botão de Chat no topo para acesso rápido
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(otherUserId: widget.studentId, otherUserName: widget.studentName),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- CABEÇALHO FIXO (Avatar e Info) ---
          _buildHeader(),

          // --- TAB BAR (Navegação) ---
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.secondary, // Neon
              labelColor: AppColors.secondary,
              unselectedLabelColor: Colors.white60,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: "Treinos"),
                Tab(text: "Anamnese"),
                Tab(text: "Avaliações"),
              ],
            ),
          ),

          // --- CONTEÚDO DAS ABAS ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ABA 1: TREINOS (Seu código antigo adaptado)
                _buildWorkoutTab(),

                // ABA 2: ANAMNESE (Novo)
                AnamneseTab(studentId: widget.studentId),

                // ABA 3: AVALIAÇÕES FÍSICAS (Novo)
                AssessmentsTab(studentId: widget.studentId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET DO CABEÇALHO ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.studentId).snapshots(),
            builder: (context, snapshot) {
              String? photoUrl;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                photoUrl = data['photoUrl'];
              }
              return UserAvatar(
                photoUrl: photoUrl,
                name: widget.studentName,
                radius: 40,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            widget.studentName, 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          Text(
            widget.studentEmail, 
            style: const TextStyle(color: Colors.white60, fontSize: 14)
          ),
        ],
      ),
    );
  }

  // --- ABA DE TREINOS (Reaproveitando sua lógica antiga) ---
  Widget _buildWorkoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // CARD: PLANEJAR TREINO
          _buildActionCard(
            icon: Icons.edit_calendar,
            color: Colors.blueAccent,
            title: "Planejar Treino Semanal",
            subtitle: "Defina os exercícios de Seg a Dom",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeeklyPlanPage(
                    studentId: widget.studentId, 
                    studentName: widget.studentName
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),

          // CARD: HISTÓRICO
          _buildActionCard(
            icon: Icons.history,
            color: Colors.orangeAccent,
            title: "Histórico de Execução",
            subtitle: "Veja o que o aluno concluiu",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutHistoryPage(studentId: widget.studentId),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          
          // CARD: DESVINCULAR (Mantendo a funcionalidade)
          _buildActionCard(
            icon: Icons.person_remove_outlined,
            color: Colors.redAccent,
            title: "Desvincular Aluno",
            subtitle: "Remover acesso aos treinos",
            onTap: () {
               _confirmarDesvinculo(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  void _confirmarDesvinculo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Desvincular?", style: TextStyle(color: Colors.white)),
        content: Text("Deseja remover ${widget.studentName}? Ele não verá mais seus treinos.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              // Lógica de desvincular (Simplificada aqui, idealmente chame uma função do controller)
              await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
                'personalId': FieldValue.delete(),
                'personalName': FieldValue.delete(),
                'inviteFromPersonalId': FieldValue.delete(),
              });
              if (mounted) {
                Navigator.pop(context); // Fecha Dialog
                Navigator.pop(context); // Fecha Página
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aluno desvinculado.")));
              }
            },
            child: const Text("Confirmar", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
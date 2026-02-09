import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Importações dos seus componentes e páginas
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/services/auth_service.dart';
import 'weekly_plan_page.dart'; 
import 'tarefas_page.dart';     
import 'profile_page.dart';
import 'students_page.dart';    
import 'chat_page.dart';
import '../../../../core/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  String _getDiaSemanaKey() {
    final now = DateTime.now();
    const dias = {1: 'segunda', 2: 'terca', 3: 'quarta', 4: 'quinta', 5: 'sexta', 6: 'sabado', 7: 'domingo'};
    return dias[now.weekday] ?? 'segunda';
  }

  String _getNomeDiaSemana() {
    return DateFormat('EEEE', 'pt_BR').format(DateTime.now()); 
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      // O background já vem do tema, mas garantimos aqui
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        // AppBar transparente
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Olá!");
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final nome = data?['name']?.toString().split(' ').first ?? 'Atleta';
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Olá, $nome 👋", style: const TextStyle(color: AppColors.textMain, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Vamos treinar?", style: const TextStyle(color: AppColors.textSub, fontSize: 14, fontWeight: FontWeight.normal)),
              ],
            );
          },
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
            builder: (context, snapshot) {
              String? photoUrl;
              String name = "";
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                photoUrl = data['photoUrl'];
                name = data['name'] ?? "";
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: UserAvatar(
                  photoUrl: photoUrl,
                  name: name,
                  radius: 20,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TÍTULO SEÇÃO ---
            const Text("TREINO DE HOJE", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('workout_plans').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final diaKey = _getDiaSemanaKey();
                final diaNome = _getNomeDiaSemana().toUpperCase();

                List<dynamic> exerciciosHoje = [];
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  exerciciosHoje = data[diaKey] as List<dynamic>? ?? [];
                }

                // Estado: Dia de Descanso
                if (exerciciosHoje.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      // Gradiente Dark Tech
                      gradient: LinearGradient(colors: [AppColors.surface, AppColors.background]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.spa, color: AppColors.textSub, size: 40),
                        const SizedBox(height: 10),
                        Text(diaNome, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                        const Text("Descanso", style: TextStyle(color: AppColors.textMain, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                // Estado: Tem Treino!
                final primeiroExercicio = exerciciosHoje.first['nome'] ?? 'Treino';
                final totalExercicios = exerciciosHoje.length;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => WeeklyPlanPage(studentId: user!.uid, studentName: "Meus Treinos")));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      // Gradiente Terracota Sutil
                      gradient: LinearGradient(colors: [
                         AppColors.primary.withOpacity(0.8), 
                         AppColors.primary.withOpacity(0.4)
                      ]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                              child: Text(diaNome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const Icon(Icons.fitness_center, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text("$totalExercicios Exercícios", style: const TextStyle(color: Colors.white70)),
                        Text(
                          "Foco: ${primeiroExercicio.split(' ')[0]}...", 
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Text("INICIAR", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward, size: 16, color: AppColors.secondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- MENU RÁPIDO ---
            const Text("MENU RÁPIDO", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.check_circle_outline,
                    color: AppColors.secondary, // Neon
                    title: "Metas",
                    subtitle: "Foco!",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TarefasPage())),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.calendar_month,
                    color: AppColors.primary, // Terracota
                    title: "Semana",
                    subtitle: "Planejamento",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WeeklyPlanPage(studentId: user!.uid, studentName: "Meus Treinos"))),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final tipo = data['tipo'];
                  
                  if (tipo == 'personal') {
                    return _buildMenuCard(
                      icon: Icons.people_outline,
                      color: Colors.purpleAccent,
                      title: "Meus Alunos",
                      subtitle: "Gerenciar Atletas",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsPage())),
                    );
                  }

                  if (tipo == 'aluno' && data['personalId'] != null) {
                    final personalName = data['personalName'] ?? 'Treinador';
                    return _buildMenuCard(
                      icon: Icons.support_agent,
                      color: Colors.blueAccent,
                      title: "Meu Personal",
                      subtitle: "Falar com $personalName",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(otherUserId: data['personalId'], otherUserName: personalName)));
                      },
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface, // Card escuro
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain), overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSub, fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
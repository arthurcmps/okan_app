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
import 'chat_page.dart'; // <--- ADICIONADO: Importante para o chat funcionar

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  // Mapeia o dia da semana do Dart (1=Seg, 7=Dom) para as chaves do nosso banco
  String _getDiaSemanaKey() {
    final now = DateTime.now();
    const dias = {
      1: 'segunda',
      2: 'terca',
      3: 'quarta',
      4: 'quinta',
      5: 'sexta',
      6: 'sabado',
      7: 'domingo'
    };
    return dias[now.weekday] ?? 'segunda';
  }

  String _getNomeDiaSemana() {
    return DateFormat('EEEE', 'pt_BR').format(DateTime.now()); 
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                Text("Olá, $nome 👋", style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Vamos treinar?", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal)),
              ],
            );
          },
        ),
        actions: [
          // Ícone de Perfil no Canto
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
            // --- CARD DE TREINO DE HOJE (DINÂMICO) ---
            const Text("TREINO DE HOJE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('workout_plans').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                // Estado: Carregando
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final diaKey = _getDiaSemanaKey();
                final diaNome = _getNomeDiaSemana().toUpperCase();

                // Verifica se existe treino para hoje
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
                      gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.blue.shade500]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.spa, color: Colors.white, size: 40),
                        const SizedBox(height: 10),
                        Text(diaNome, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        const Text("Descanso Merecido", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("Recupere as energias para amanhã!", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                }

                // Estado: Tem Treino!
                final primeiroExercicio = exerciciosHoje.first['nome'] ?? 'Treino';
                final totalExercicios = exerciciosHoje.length;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeeklyPlanPage(studentId: user!.uid, studentName: "Meus Treinos"),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
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
                            Text("Toque para iniciar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward, size: 16, color: Colors.blueAccent),
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
            const Text("MENU RÁPIDO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    title: "Metas",
                    subtitle: "Foco!",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TarefasPage())),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.calendar_month,
                    color: Colors.orange,
                    title: "Semana",
                    subtitle: "Planejamento",
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => WeeklyPlanPage(studentId: user!.uid, studentName: "Meus Treinos"),
                      )
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // --- ÁREA DINÂMICA (PERSONAL vs ALUNO) ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final tipo = data['tipo'];
                  
                  // 1. SE FOR PERSONAL: Vê "Meus Alunos"
                  if (tipo == 'personal') {
                    return _buildMenuCard(
                      icon: Icons.people_outline,
                      color: Colors.purple,
                      title: "Meus Alunos",
                      subtitle: "Gerenciar Atletas",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsPage())),
                    );
                  }

                  // 2. SE FOR ALUNO E TIVER PERSONAL: Vê "Falar com Personal"
                  if (tipo == 'aluno' && data['personalId'] != null) {
                    final personalName = data['personalName'] ?? 'Treinador';
                    return _buildMenuCard(
                      icon: Icons.support_agent, // Ícone de suporte/chat
                      color: Colors.blueAccent,
                      title: "Meu Personal",
                      subtitle: "Falar com $personalName",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              otherUserId: data['personalId'],
                              otherUserName: personalName,
                            ),
                          ),
                        );
                      },
                    );
                  }
                }
                // Se for aluno sem personal, não mostra nada extra por enquanto
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded( // Adicionado Expanded para evitar overflow de texto
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
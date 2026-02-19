import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS ---
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart'; 
import 'chat_page.dart';
import 'weekly_plan_page.dart'; 
import 'workout_history_page.dart';
import 'anamnese_tab.dart'; 
import 'assessments_tab.dart'; 

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

  // --- HELPER: CALCULAR IDADE ---
  String _calcularIdade(dynamic dataNascimento) {
    if (dataNascimento == null) return "--"; 
    DateTime nascimento;
    
    if (dataNascimento is Timestamp) {
      nascimento = dataNascimento.toDate();
    } else if (dataNascimento is DateTime) {
       nascimento = dataNascimento;
    } else {
      return "--";
    }

    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month || (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return "$idade anos";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: const Text("Perfil do Aluno"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
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
              indicatorColor: AppColors.primary, // Neon
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white60,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
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
                _buildWorkoutTab(),
                AnamneseTab(studentId: widget.studentId, isEditable: false), // Personal apenas visualiza ou edita notas
                AssessmentsTab(studentId: widget.studentId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET DO CABEÇALHO ATUALIZADO ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.studentId).snapshots(),
        builder: (context, snapshot) {
          String? photoUrl;
          String idade = "--";
          String genero = "Não informado";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            photoUrl = data['photoUrl'];
            
            // Pega dados novos
            idade = _calcularIdade(data['birthDate'] ?? data['dataNascimento']);
            genero = data['gender'] ?? "Não informado";
          }

          return Column(
            children: [
              UserAvatar(
                photoUrl: photoUrl,
                name: widget.studentName,
                radius: 40,
              ),
              const SizedBox(height: 12),
              Text(
                widget.studentName, 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const SizedBox(height: 4),
              Text(
                widget.studentEmail, 
                style: const TextStyle(color: Colors.white60, fontSize: 14)
              ),
              
              const SizedBox(height: 12),

              // --- TAGS DE IDADE E GÊNERO ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tag Idade (Neon)
                  if (idade != "--") ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.5))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(idade, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Tag Gênero (Terracota)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.5))
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text(genero, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  // --- ABA DE TREINOS ---
  Widget _buildWorkoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // CARD: PLANEJAR TREINO
          _buildActionCard(
            icon: Icons.edit_calendar,
            color: AppColors.primary, // Neon
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
            color: Colors.white, // Branco para diferenciar
            title: "Histórico de Execução",
            subtitle: "Veja o que o aluno concluiu",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutHistoryPage(studentId: widget.studentId, studentName: widget.studentName),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          
          // CARD: DESVINCULAR
          _buildActionCard(
            icon: Icons.person_remove_outlined,
            color: AppColors.error,
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
          borderRadius: BorderRadius.circular(16), // Bordas mais arredondadas (estilo novo)
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        title: const Text("Desvincular?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Deseja remover ${widget.studentName}? Ele não verá mais seus treinos.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
                'personalId': FieldValue.delete(),
                'personalName': FieldValue.delete(),
                'inviteFromPersonalId': FieldValue.delete(),
              });
              if (mounted) {
                Navigator.pop(context); 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aluno desvinculado."), backgroundColor: AppColors.primary));
              }
            },
            child: const Text("Confirmar", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
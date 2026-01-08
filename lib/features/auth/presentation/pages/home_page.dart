import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';

// IMPORTS DAS PÁGINAS (Certifique-se de que os arquivos existem)
import 'login_page.dart';
import 'dashboard_chart.dart';
import 'train_page.dart';
import 'profile_page.dart';
import 'create_workout_page.dart';
import 'students_page.dart';
import 'invite_student_page.dart'; 
import 'notifications_page.dart';
import 'chat_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String _nomeUsuario = "Atleta";
  String _tipoUsuario = "aluno"; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final nome = user.displayName ?? user.email?.split('@')[0] ?? "Atleta";
      final tipo = await _authService.obterTipoUsuario();

      if (mounted) {
        setState(() {
          _nomeUsuario = nome;
          _tipoUsuario = tipo;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isPersonal = _tipoUsuario == 'personal';
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Olá, $_nomeUsuario", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            Text(isPersonal ? "PAINEL DO COACH" : "VAMOS TREINAR", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // 1. SINO DE NOTIFICAÇÕES (Só aparece para o Aluno)
          if (!isPersonal) 
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('invites')
                  .where('toStudentEmail', isEqualTo: user?.email)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text("$count"),
                    child: const Icon(Icons.notifications_none, size: 28),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
                  },
                );
              },
            ),

          // 2. PERFIL
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            tooltip: "Meu Perfil",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
          ),

          // 3. SAIR
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            tooltip: "Sair",
            onPressed: () async {
              await _authService.deslogar();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gráfico de atividades (Comum a todos)
            const DashboardChart(),
            
            const SizedBox(height: 24),

            // --- ÁREA ESPECÍFICA DO TIPO DE USUÁRIO ---
            if (isPersonal) ...[
              _buildSectionTitle("Gerenciamento"),
              
              // Convidar Aluno
              _buildActionCard(
                icon: Icons.person_add,
                color: Colors.orange,
                title: "Convidar Aluno",
                subtitle: "Enviar solicitação por e-mail",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InviteStudentPage()));
                },
              ),

              // Ver Lista de Alunos
              _buildActionCard(
                icon: Icons.people_alt,
                color: Colors.blue,
                title: "Meus Alunos",
                subtitle: "Gerenciar fichas e chat",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsPage()));
                },
              ),

              // Criar Treino (CRUD)
              _buildActionCard(
                icon: Icons.add_circle_outline,
                color: Colors.purple,
                title: "Criar Novo Treino",
                subtitle: "Montar template de exercícios",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateWorkoutPage()));
                },
              ),

            ] else ...[
              _buildSectionTitle("Seu Plano"),
              
              // Acessar Treino Dinâmico
              _buildActionCard(
                icon: Icons.calendar_today, // Ícone mudou para calendário
                color: Colors.green,
                title: "Treino de Hoje",
                subtitle: "Verificar cronograma",
                onTap: () async {
                  if (user != null) {
                    try {
                      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                      
                      // 1. Descobrir que dia é hoje (1=Segunda ... 7=Domingo)
                      final hoje = DateTime.now().weekday.toString();
                      
                      // 2. Buscar o mapa de treinos
                      final data = doc.data();
                      final weeklyWorkouts = data != null && data['weeklyWorkouts'] != null 
                          ? Map<String, dynamic>.from(data['weeklyWorkouts']) 
                          : {};

                      // 3. Verificar se tem treino hoje
                      final treinoHoje = weeklyWorkouts[hoje];

                      if (mounted) {
                        if (treinoHoje == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Nenhum treino agendado para hoje. Fale com seu personal."), backgroundColor: Colors.orange)
                          );
                        } else if (treinoHoje['id'] == 'rest') {
                          // Se for dia de descanso
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Dia de Descanso 😴"),
                              content: const Text("Hoje é dia de recuperar! Aproveite para descansar."),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Beleza!"))],
                            ),
                          );
                        } else {
                          // Se tiver treino, abre a execução
                          Navigator.push(context, MaterialPageRoute(builder: (context) => TrainPage(workoutId: treinoHoje['id'])));
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao carregar: $e")));
                    }
                  }
                },
              ),

              // Falar com o Personal (Chat)
              _buildActionCard(
                icon: Icons.chat,
                color: Colors.purple,
                title: "Meu Personal",
                subtitle: "Falar com o coach",
                onTap: () async {
                  if (user != null) {
                    // Busca quem é o personal deste aluno
                    final studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final personalId = studentDoc.data()?['personalId'];

                    if (mounted) {
                      if (personalId != null && personalId.isNotEmpty) {
                        // Busca o nome do personal para exibir na topo do chat
                        final personalDoc = await FirebaseFirestore.instance.collection('users').doc(personalId).get();
                        final personalName = personalDoc.data()?['nome'] ?? personalDoc.data()?['name'] ?? "Personal";

                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(
                          otherUserId: personalId,
                          otherUserName: personalName,
                        )));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Você ainda não tem um personal vinculado."), backgroundColor: Colors.orange)
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
    );
  }

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
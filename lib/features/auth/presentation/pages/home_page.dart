import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'weekly_plan_page.dart'; 
import 'tarefas_page.dart';     
import 'profile_page.dart';
import 'students_page.dart';    
import 'chat_page.dart';
import 'notifications_page.dart'; 
import 'arena_page.dart';
import '../../../../core/theme/app_colors.dart';
import 'discover_workouts_page.dart'; // IMPORT DA LOJA

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

  // --- O BANNER DA VITRINE PREMIUM ---
  Widget _buildBannerDescobrirTreinos(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const DiscoverWorkoutsPage())
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Gradiente chamativo usando as cores Cyber-Sankofa
          gradient: LinearGradient(
            colors: [AppColors.secondary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Descubra Novos Treinos", 
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Encontre fichas premium perfeitas para o seu perfil e nível.", 
                    style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.black, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // --- TÍTULO (Saudação Inteligente) ---
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
          builder: (context, snapshot) {
            String nomeExibicao = 'Atleta';

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final nomeCompleto = data?['name'] ?? data?['nome'] ?? 'Atleta';
              nomeExibicao = nomeCompleto.toString().split(' ').first;
            } else if (user?.displayName != null) {
              nomeExibicao = user!.displayName!.split(' ').first;
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Olá, $nomeExibicao 👋", style: const TextStyle(color: AppColors.textMain, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Vamos treinar?", style: TextStyle(color: AppColors.textSub, fontSize: 14, fontWeight: FontWeight.normal)),
              ],
            );
          },
        ),
        
        // --- AÇÕES DA BARRA SUPERIOR ---
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('invites')
                .where('toStudentEmail', isEqualTo: user?.email)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshotInvites) {
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshotNotifs) {
                  
                  bool temConvite = snapshotInvites.hasData && snapshotInvites.data!.docs.isNotEmpty;
                  bool temNotificacaoNova = snapshotNotifs.hasData && snapshotNotifs.data!.docs.isNotEmpty;
                  bool mostrarAlerta = temConvite || temNotificacaoNova;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
                        },
                      ),
                      if (mostrarAlerta)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, 
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
            builder: (context, snapshot) {
              String? photoUrl;
              String name = "";
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                photoUrl = data['photoUrl'];
                name = data['name'] ?? data['nome'] ?? "";
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16.0, left: 8.0),
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

      // --- CORPO DA PÁGINA ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEÇÃO: TREINO DE HOJE
            const Text("TREINO DE HOJE", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('workout_plans').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                }

                final diaKey = _getDiaSemanaKey();
                final diaNome = _getNomeDiaSemana().toUpperCase();

                List<dynamic> exerciciosHoje = [];
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  exerciciosHoje = data[diaKey] as List<dynamic>? ?? [];
                }

                if (exerciciosHoje.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.surface, AppColors.background]),
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
                      gradient: LinearGradient(colors: [
                          AppColors.primary.withOpacity(0.9), 
                          AppColors.primary.withOpacity(0.6)
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
                            Text("INICIAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward, size: 16, color: Colors.black),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // SEÇÃO: MENU RÁPIDO
            const Text("MENU RÁPIDO", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.check_circle_outline,
                    color: AppColors.secondary,
                    title: "Metas",
                    subtitle: "Foco!",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TarefasPage())),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.calendar_month,
                    color: AppColors.primary,
                    title: "Semana",
                    subtitle: "Planejamento",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WeeklyPlanPage(studentId: user!.uid, studentName: "Meus Treinos"))),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // CARDS ESPECÍFICOS (Personal ou Aluno) E BANNER DA LOJA
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final tipo = data['tipo'];
                  final isPersonal = tipo == 'personal' || data['role'] == 'personal';
                  final temPersonal = data['personalId'] != null && data['personalId'].toString().isNotEmpty;

                  List<Widget> cardsSecao = [];

                  // SE FOR ALUNO E NÃO TIVER PERSONAL, MOSTRA A LOJA!
                  if (!isPersonal && !temPersonal) {
                    cardsSecao.add(_buildBannerDescobrirTreinos(context));
                    cardsSecao.add(const SizedBox(height: 16));
                  }
                  
                  // Se for PERSONAL
                  if (isPersonal) {
                    cardsSecao.add(
                      _buildMenuCard(
                        icon: Icons.people_outline,
                        color: Colors.purpleAccent,
                        title: "Meus Alunos",
                        subtitle: "Gerenciar Atletas",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsPage())),
                      )
                    );
                  }

                  // Se for ALUNO
                  if (!isPersonal) {
                    // Card do Personal (só exibe se tiver personalId)
                    if (temPersonal) {
                      cardsSecao.add(
                        _buildMenuCard(
                          icon: Icons.support_agent,
                          color: Colors.blueAccent,
                          title: "Meu Personal",
                          subtitle: "Falar com ${data['personalName'] ?? 'Treinador'}",
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(otherUserId: data['personalId'], otherUserName: data['personalName'] ?? 'Treinador')));
                          },
                        )
                      );
                      cardsSecao.add(const SizedBox(height: 16));
                    }
                    
                    // --- ARENA OKAN ---
                    cardsSecao.add(
                      _buildMenuCard(
                        icon: Icons.sports_martial_arts,
                        color: Colors.deepOrangeAccent,
                        title: "Arena Okan ⚔️",
                        subtitle: "Busque e desafie amigos!",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ArenaPage())),
                      )
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cardsSecao,
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 30),

            // --- SEÇÃO BETA FEEDBACK ---
            const Text("FASE DE TESTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _buildMenuCard(
              icon: Icons.bug_report,
              color: Colors.amber,
              title: "Deixar Feedback (Beta)",
              subtitle: "Ajude a melhorar o Okan!",
              onTap: () => mostrarFormularioFeedbackBeta(context),
            ),
            
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildMenuCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
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

  Widget _buildFeedbackInput(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // =========================================================================
  // LÓGICA DO FORMULÁRIO DE FEEDBACK BETA
  // =========================================================================
  void mostrarFormularioFeedbackBeta(BuildContext context) {
    if (user == null) return;

    final TextEditingController confusoCtrl = TextEditingController();
    final TextEditingController bugCtrl = TextEditingController();
    final TextEditingController gostouCtrl = TextEditingController();
    double notaGeral = 5.0; 
    bool enviando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85, 
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 20, right: 20, top: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.amber),
                      SizedBox(width: 10),
                      Text("Feedback de Teste (Beta)", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Sua opinião vai ajudar a polir o Okan antes do lançamento oficial!", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView(
                      children: [
                        const Text("1. Que nota você dá para o app?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Slider(
                          value: notaGeral,
                          min: 1, max: 5, divisions: 4,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white12,
                          label: notaGeral.toInt().toString(),
                          onChanged: (val) => setStateModal(() => notaGeral = val),
                        ),
                        Center(child: Text("${notaGeral.toInt()} de 5 Estrelas", style: const TextStyle(color: Colors.white))),
                        const SizedBox(height: 20),

                        const Text("2. O que achou mais confuso ou difícil de usar?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildFeedbackInput(confusoCtrl, "Ex: Não entendi como adicionar a carga..."),
                        const SizedBox(height: 20),

                        const Text("3. Encontrou algum erro (bug)? Onde?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildFeedbackInput(bugCtrl, "Ex: O botão X travou a tela..."),
                        const SizedBox(height: 20),

                        const Text("4. O que você mais gostou?", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildFeedbackInput(gostouCtrl, "Ex: Achei as cores incríveis..."),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: enviando ? null : () async {
                        setStateModal(() => enviando = true);
                        
                        try {
                          await FirebaseFirestore.instance.collection('beta_feedback').add({
                            'userId': user!.uid,
                            'timestamp': FieldValue.serverTimestamp(),
                            'nota': notaGeral.toInt(),
                            'confuso': confusoCtrl.text,
                            'bugs': bugCtrl.text,
                            'gostou': gostouCtrl.text,
                            'status': 'novo', 
                          });
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback enviado! Muito obrigado! 💙"), backgroundColor: Colors.amber));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                          setStateModal(() => enviando = false);
                        }
                      },
                      child: enviando 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("ENVIAR FEEDBACK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }
}
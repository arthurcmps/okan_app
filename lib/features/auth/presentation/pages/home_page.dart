import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/auth_service.dart'; // Importe o seu serviço aqui
import 'train_page.dart'; // Sua página de treino
import 'login_page.dart';
import 'dashboard_chart.dart'; // O gráfico que criamos

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String _nomeUsuario = "Atleta";
  String _tipoUsuario = "aluno"; // 'personal' ou 'aluno'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Pega o nome (pode vir do Auth ou do Firestore se quiser mais completo)
      final nome = user.displayName ?? user.email?.split('@')[0] ?? "Atleta";
      
      // Pega o tipo (Personal ou Aluno) usando nosso serviço
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

  void _deslogar() async {
    await _authService.deslogar();
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const LoginPage())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPersonal = _tipoUsuario == 'personal';

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
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: _deslogar,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. O GRÁFICO (Visível para todos ou só para aluno?)
            // Vamos deixar para todos por enquanto
            const DashboardChart(),
            
            const SizedBox(height: 24),

            // 2. SEÇÃO ESPECÍFICA DO TIPO DE USUÁRIO
            if (isPersonal) ...[
              _buildSectionTitle("Gerenciamento"),
              _buildActionCard(
                icon: Icons.people_alt,
                color: Colors.blue,
                title: "Meus Alunos",
                subtitle: "Gerenciar fichas e progressão",
                onTap: () {
                  // TODO: Navegar para lista de alunos
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Em breve: Lista de Alunos")));
                },
              ),
              _buildActionCard(
                icon: Icons.add_circle_outline,
                color: Colors.orange,
                title: "Criar Novo Treino",
                subtitle: "Montar template de treino",
                onTap: () {
                  // TODO: Navegar para criador de treino
                },
              ),
            ] else ...[
              _buildSectionTitle("Seu Plano"),
              _buildActionCard(
                icon: Icons.fitness_center,
                color: Colors.green,
                title: "Treino de Hoje",
                subtitle: "Peito e Tríceps (Exemplo)", // Futuramente dinâmico
                onTap: () {
                  // Vai para a tela de treino que já criamos
                   Navigator.push(context, MaterialPageRoute(builder: (context) => 
                     const TreinoDetalhesPage(nomeTreino: "Treino A", grupoMuscular: "Peito", treinoId: "id_fixo_teste")
                   ));
                },
              ),
              _buildActionCard(
                icon: Icons.person_pin,
                color: Colors.purple,
                title: "Meu Personal",
                subtitle: "Falar com o coach",
                onTap: () {},
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
        // O CardTheme do main.dart vai estilizar isso automaticamente
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
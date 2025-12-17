import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'train_page.dart';
import 'profile_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controladores
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  // Função para criar novo treino
  void _mostrarDialogoCriar() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Novo Treino"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome (ex: Treino A)"),
              ),
              TextField(
                controller: _grupoController,
                decoration: const InputDecoration(labelText: "Foco (ex: Peito/Tríceps)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                
                // SEGURANÇA: Só cria se tiver usuário logado
                if (user == null) return; 

                // 1. Salva no Firebase COM O ID DO DONO
                await FirebaseFirestore.instance.collection('treinos').add({
                  'userId': user.uid, // <--- O SEGREDO ESTÁ AQUI 
                  'nome': _nomeController.text.isNotEmpty ? _nomeController.text : 'Treino Novo',
                  'grupo': _grupoController.text.isNotEmpty ? _grupoController.text : 'Geral',
                  'qtd_exercicios': 0,
                  'duracao': '?? min',
                  'criadoEm': FieldValue.serverTimestamp(), // Para ordenar depois
                });

                _nomeController.clear();
                _grupoController.clear();

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Criar"),
            ),
          ],
        );
      },
    );
  }

  // Função de Logout completa
  Future<void> _fazerLogout() async {
    try {
      // 1. Deslogar do Google (se estiver logado)
      await GoogleSignIn().signOut();
      
      // 2. Deslogar do Firebase
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        // 3. A CORREÇÃO: Navegar para Login e REMOVER tudo que ficou para trás
        // Isso impede que o app feche ou que o botão "voltar" funcione
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false, // A regra "false" remove todas as rotas anteriores
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user?.displayName ?? "Atleta";

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${nomeUsuario.split(' ')[0]}', // Pega só o primeiro nome
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Bora treinar?',
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sair',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seus Treinos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // FILTRO DE SEGURANÇA: Traz apenas treinos do meu ID
                stream: FirebaseFirestore.instance
                    .collection('treinos')
                    .where('userId', isEqualTo: user?.uid) 
                    // .orderBy('criadoEm', descending: true) // Se descomentar, vai pedir índice!
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final dados = snapshot.data?.docs;
                  
                  if (dados == null || dados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Nenhum treino encontrado.', style: TextStyle(color: Colors.grey)),
                          const Text('Clique no (+) para criar o seu primeiro!', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: dados.length,
                    itemBuilder: (context, index) {
                      final treino = dados[index].data() as Map<String, dynamic>;
                      final nome = treino['nome']?.toString() ?? 'Sem nome';
                      final grupo = treino['grupo']?.toString() ?? 'Geral';
                      final qtd = treino['qtd_exercicios']?.toString() ?? '0';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TreinoDetalhesPage(
                                  nomeTreino: nome,
                                  grupoMuscular: grupo,
                                  treinoId: dados[index].id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : "T", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(grupo, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.fitness_center, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text("$qtd exercícios", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _mostrarDialogoCriar,
      ),
    );
  }
}
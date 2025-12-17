import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'train_page.dart'; // Sua página de detalhes
import 'profile_page.dart'; // Sua página de perfil/histórico

class HomePage extends StatelessWidget {
  // Removemos o 'const' aqui porque agora temos controladores
  HomePage({super.key});

  // Controladores para capturar o texto na hora de criar treino
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  // Função para abrir o formulário de criar treino
  void _mostrarDialogoCriar(BuildContext context) {
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
                decoration: const InputDecoration(labelText: "Nome (ex: Treino C)"),
              ),
              TextField(
                controller: _grupoController,
                decoration: const InputDecoration(labelText: "Grupo (ex: Pernas)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancelar
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                // 1. Salva no Firebase (Banco padrão)
                FirebaseFirestore.instance.collection('treinos').add({
                  'nome': _nomeController.text.isNotEmpty ? _nomeController.text : 'Treino Novo',
                  'grupo': _grupoController.text.isNotEmpty ? _grupoController.text : 'Geral',
                  'qtd_exercicios': 0,
                  'duracao': '?? min',
                });

                // 2. Limpa os campos
                _nomeController.clear();
                _grupoController.clear();

                // 3. Fecha a janela
                Navigator.pop(context);
              },
              child: const Text("Criar"),
            ),
          ],
        );
      },
    );
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
              'Olá, $nomeUsuario',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Vamos treinar hoje?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // BOTÃO PERFIL (HISTÓRICO)
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
          // BOTÃO LOGOUT
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
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

            // LISTA DE TREINOS (STREAM)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Conecta ao banco padrão (Default)
                stream: FirebaseFirestore.instance.collection('treinos').snapshots(),
                builder: (context, snapshot) {
                  // 1. Erro
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }

                  // 2. Carregando
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 3. Verifica se tem dados
                  final dados = snapshot.data?.docs;
                  if (dados == null || dados.isEmpty) {
                    return const Center(
                      child: Text('Nenhum treino encontrado. Crie um no botão (+)!'),
                    );
                  }

                  // 4. Lista Sucesso
                  return ListView.builder(
                    itemCount: dados.length,
                    itemBuilder: (context, index) {
                      final treino = dados[index].data() as Map<String, dynamic>;
                      
                      // Tratamento de nulos com ??
                      final nome = treino['nome']?.toString() ?? 'Treino sem nome';
                      final grupo = treino['grupo']?.toString() ?? 'Geral';
                      final duracao = treino['duracao']?.toString() ?? '--';
                      final qtd = treino['qtd_exercicios']?.toString() ?? '0';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TreinoDetalhesPage(
                                  nomeTreino: nome,
                                  grupoMuscular: grupo,
                                  treinoId: dados[index].id, // Envia o ID para buscar exercícios
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      nome.isNotEmpty ? nome[0].toUpperCase() : "T",
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        grupo,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(duracao, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                          const SizedBox(width: 12),
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
      
      // BOTÃO FLUTUANTE PARA CRIAR TREINOS
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _mostrarDialogoCriar(context);
        },
      ),
    );
  }
}
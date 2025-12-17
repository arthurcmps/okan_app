import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'train_page.dart';
import 'profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Pega os dados do usuário logado de forma segura
    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user?.displayName ?? "Atleta";

    return Scaffold(
      appBar: AppBar(
        // Remove a sombra do AppBar para um visual mais limpo
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black, // Cor dos ícones e texto
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
          // BOTÃO PERFIL (NOVO)
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
          // Botão de Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Volta para a tela de login removendo o histórico
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

            // O StreamBuilder que ouve o Firebase
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // ATENÇÃO: O nome 'treinos' aqui tem que ser IGUAL ao do site (minúsculo/maiúsculo)
                stream: FirebaseFirestore.instance.collection('treinos').snapshots(),
                builder: (context, snapshot) {
                  
                  // 1. Tratamento de ERRO
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 50, color: Colors.red),
                          const SizedBox(height: 10),
                          Text(
                            'Erro ao carregar:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // 2. Estado de CARREGAMENTO
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // 3. Verifica se veio VAZIO (Correção do erro Null Check)
                  final dados = snapshot.data?.docs;
                  if (dados == null || dados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum treino encontrado.\nVerifique se a coleção "treinos" existe no Firebase.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  // 4. Lista SUCESSO
                  return ListView.builder(
                    itemCount: dados.length,
                    itemBuilder: (context, index) {
                      // Converte o documento para Map de forma segura
                      final treino = dados[index].data() as Map<String, dynamic>;

                      // Usa '??' para evitar erro se faltar campo no banco
                      final nome = treino['nome'] ?? 'Treino sem nome';
                      final grupo = treino['grupo'] ?? 'Geral';
                      final duracao = treino['duracao'] ?? '--';
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
                                  treinoId: dados[index].id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Ícone/Letra do Treino
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
                                
                                // Textos do Treino
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
                                          Text(
                                            duracao,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.format_list_bulleted, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$qtd exercícios",
                                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                          ),
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
    );
  }
}
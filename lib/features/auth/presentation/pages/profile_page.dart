import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'library_admin_page.dart'; // Para o Personal acessar a biblioteca
import '../../../../core/services/auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;

  // Controladores para edição (Futuro)
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _alturaController = TextEditingController();

  Future<void> _editarDados(BuildContext context, String campo, String valorAtual) async {
    final controller = TextEditingController(text: valorAtual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar $campo"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Novo $campo"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  campo.toLowerCase(): controller.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Usuário não logado.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // AQUI ESTÁ A CORREÇÃO: Buscando dados em tempo real do Firestore
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Perfil não encontrado no banco de dados."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          final String nome = data['name'] ?? data['nome'] ?? user?.displayName ?? "Usuário";
          final String email = data['email'] ?? user?.email ?? "";
          final String tipo = data['tipo'] ?? data['role'] ?? "aluno";
          final String peso = data['peso'] ?? "--";
          final String altura = data['altura'] ?? "--";
          
          final bool isPersonal = tipo == 'personal';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // FOTO E NOME
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: isPersonal ? Colors.purple.shade100 : Colors.blue.shade100,
                        child: Text(
                          nome[0].toUpperCase(),
                          style: TextStyle(fontSize: 40, color: isPersonal ? Colors.purple : Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPersonal ? Colors.purple : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPersonal ? "PERSONAL TRAINER" : "ALUNO",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(email, style: const TextStyle(color: Colors.grey, height: 2)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // DADOS FÍSICOS (Só mostra se for Aluno)
                if (!isPersonal) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text("Dados Físicos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.monitor_weight_outlined,
                          title: "Peso",
                          value: "$peso kg",
                          onTap: () => _editarDados(context, "Peso", peso),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.height,
                          title: "Altura",
                          value: "$altura cm",
                          onTap: () => _editarDados(context, "Altura", altura),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],

                // MENU DE CONFIGURAÇÕES
                const Align(alignment: Alignment.centerLeft, child: Text("Configurações", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 10),
                
                if (isPersonal)
                  ListTile(
                    leading: const Icon(Icons.library_books, color: Colors.purple),
                    title: const Text("Gerenciar Biblioteca de Exercícios"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryAdminPage()));
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.grey),
                  title: const Text("Alterar Senha"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Implementar lógica de redefinição de senha
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Função em desenvolvimento")));
                  },
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Sair da Conta", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await _authService.deslogar();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/storage_service.dart'; // <--- Importe o novo serviço
import 'library_admin_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService(); // <--- Instância do Storage
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;

  Future<void> _trocarFoto() async {
    // 1. Seleciona
    final File? imagem = await _storageService.selecionarImagem();
    if (imagem == null) return; // Usuário cancelou

    setState(() => _isUploading = true);

    // 2. Faz Upload
    final url = await _storageService.uploadFotoPerfil(imagem);

    setState(() => _isUploading = false);

    if (url != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto atualizada com sucesso!")));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao enviar foto."), backgroundColor: Colors.red));
    }
  }

  // ... (Função _editarDados continua igual)
  Future<void> _editarDados(BuildContext context, String campo, String valorAtual) async {
    final controller = TextEditingController(text: valorAtual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar $campo"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Novo $campo")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({campo.toLowerCase(): controller.text.trim()});
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
    if (user == null) return const Scaffold(body: Center(child: Text("Usuário não logado.")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String nome = data['name'] ?? data['nome'] ?? "Usuário";
          final String email = data['email'] ?? "";
          final String tipo = data['tipo'] ?? "aluno";
          final String peso = data['peso'] ?? "--";
          final String altura = data['altura'] ?? "--";
          // Pega a URL da foto (pode ser null)
          final String? photoUrl = data['photoUrl']; 

          final bool isPersonal = tipo == 'personal';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      // --- ÁREA DA FOTO ---
                      Stack(
                        children: [
                          _buildAvatar(photoUrl, nome, isPersonal),
                          if (_isUploading)
                            const Positioned.fill(child: CircularProgressIndicator()),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.blueGrey),
                                onPressed: _trocarFoto, // <--- Botão de Trocar
                              ),
                            ),
                          )
                        ],
                      ),
                      // --------------------
                      const SizedBox(height: 16),
                      Text(nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: isPersonal ? Colors.purple : Colors.blue, borderRadius: BorderRadius.circular(20)),
                        child: Text(isPersonal ? "PERSONAL TRAINER" : "ALUNO", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Text(email, style: const TextStyle(color: Colors.grey, height: 2)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // ... (O Restante do código de Dados Físicos e Configurações continua igual)
                if (!isPersonal) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text("Dados Físicos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard(icon: Icons.monitor_weight_outlined, title: "Peso", value: "$peso kg", onTap: () => _editarDados(context, "Peso", peso))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoCard(icon: Icons.height, title: "Altura", value: "$altura cm", onTap: () => _editarDados(context, "Altura", altura))),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],

                const Align(alignment: Alignment.centerLeft, child: Text("Configurações", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 10),
                
                if (isPersonal)
                  ListTile(
                    leading: const Icon(Icons.library_books, color: Colors.purple),
                    title: const Text("Gerenciar Biblioteca"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryAdminPage())),
                  ),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Sair da Conta", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await _authService.deslogar();
                    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget Auxiliar para exibir o Avatar (Imagem ou Letra)
  Widget _buildAvatar(String? url, String nome, bool isPersonal) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.grey.shade200,
      );
    }
    return CircleAvatar(
      radius: 50,
      backgroundColor: isPersonal ? Colors.purple.shade100 : Colors.blue.shade100,
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
        style: TextStyle(fontSize: 40, color: isPersonal ? Colors.purple : Colors.blue),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
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
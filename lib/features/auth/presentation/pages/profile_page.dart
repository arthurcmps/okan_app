import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'library_admin_page.dart';
import 'login_page.dart';
import 'workout_history_page.dart'; // <--- IMPORTANTE: Nova importação

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;

  // --- LÓGICA DE FOTO ---
  void _mostrarOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Tirar Foto Agora'),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _atualizarFoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile == null) return;

    File imagem = File(pickedFile.path);
    String userId = user!.uid;

    try {
      setState(() => _isUploading = true);

      final ref = FirebaseStorage.instance.ref().child('user_photos').child('$userId.jpg');
      await ref.putFile(imagem);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({'photoUrl': url});
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil atualizada! 📸"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar foto: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- LÓGICA DE DADOS ---
  Future<void> _editarDados(BuildContext context, String campo, String valorAtual) async {
    final controller = TextEditingController(text: valorAtual.replaceAll(RegExp(r'[^0-9.,]'), ''));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar $campo"),
        content: TextField(
          controller: controller, 
          keyboardType: TextInputType.number, 
          decoration: InputDecoration(labelText: "Novo $campo", suffixText: campo == "Altura" ? "cm" : "kg")
        ),
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
        centerTitle: true,
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
          final String? photoUrl = data['photoUrl']; 

          final bool isPersonal = tipo == 'personal';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      // FOTO
                      Stack(
                        children: [
                          UserAvatar(
                            photoUrl: photoUrl, 
                            name: nome, 
                            radius: 60,
                            onTap: _mostrarOpcoesFoto,
                          ),
                          if (_isUploading)
                            const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _mostrarOpcoesFoto,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]
                                ),
                                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
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
                
                // DADOS FÍSICOS (Só Aluno)
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

                // CONFIGURAÇÕES E MENU
                const Align(alignment: Alignment.centerLeft, child: Text("Configurações", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 10),
                
                // --- NOVO BOTÃO DE HISTÓRICO (Para o próprio usuário ver) ---
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.history, color: Colors.orange)),
                  title: const Text("Meu Histórico de Treinos"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutHistoryPage(studentId: user!.uid))),
                ),

                if (isPersonal)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.library_books, color: Colors.purple)),
                    title: const Text("Gerenciar Biblioteca de Exercícios"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryAdminPage())),
                  ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout, color: Colors.red)),
                  title: const Text("Sair da Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
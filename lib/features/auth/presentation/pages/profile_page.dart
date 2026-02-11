import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart';

// IMPORTS DAS NOVAS ABAS
import 'anamnese_tab.dart'; 
import 'assessments_tab.dart';

import 'library_admin_page.dart';
import 'login_page.dart';
import 'workout_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // 3 Abas: Conta, Anamnese, Medidas
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE FOTO ---
  void _mostrarOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Escolher da Galeria', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Tirar Foto Agora', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Usuário não logado.")));

    return Scaffold(
      backgroundColor: AppColors.background, // Fundo Roxo Okan
      appBar: AppBar(
        title: const Text("Meu Perfil", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        
        // --- TAB BAR NA APPBAR ---
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: AppColors.secondary,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Conta", icon: Icon(Icons.person_outline)),
            Tab(text: "Anamnese", icon: Icon(Icons.assignment_ind_outlined)),
            Tab(text: "Medidas", icon: Icon(Icons.show_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountTab(),
          AnamneseTab(studentId: user!.uid, isEditable: true),
          AssessmentsTab(studentId: user!.uid),
        ],
      ),
    );
  }

  // --- CONTEÚDO DA ABA CONTA ---
  Widget _buildAccountTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String nome = data['name'] ?? data['nome'] ?? "Usuário";
        final String email = data['email'] ?? "";
        final String tipo = data['tipo'] ?? "aluno";
        final String? photoUrl = data['photoUrl']; 
        
        // Buscamos dados motivacionais (se existirem na raiz, senão mostramos padrão)
        // DICA: Para isso aparecer aqui, idealmente salvaríamos esses campos no user doc ao salvar a anamnese.
        final String objetivo = data['objetivo'] ?? "Definir";
        final String frequencia = data['freq_semanal'] ?? "Definir";

        final bool isPersonal = tipo == 'personal';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // FOTO E INFO BÁSICA
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(
                          photoUrl: photoUrl, 
                          name: nome, 
                          radius: 60,
                          onTap: _mostrarOpcoesFoto,
                        ),
                        if (_isUploading)
                          const Positioned.fill(child: CircularProgressIndicator(color: AppColors.secondary)),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _mostrarOpcoesFoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.background, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPersonal ? Colors.purple : Colors.blueAccent, 
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        isPersonal ? "PERSONAL TRAINER" : "ALUNO", 
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                    ),
                    Text(email, style: const TextStyle(color: Colors.white60, height: 2)),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // --- CARD MOTIVACIONAL (Substitui Peso/Altura) ---
              if (!isPersonal) ...[
                Row(
                  children: [
                    // Card Objetivo
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.flag_outlined, 
                        title: "Meu Foco", 
                        value: objetivo, 
                        // Ao clicar, leva para a aba de Anamnese (Index 1)
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Card Frequência
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.calendar_today_outlined, 
                        title: "Frequência", 
                        value: frequencia, 
                        // Ao clicar, leva para a aba de Anamnese (Index 1)
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],

              // MENU DE AÇÕES
              const Align(alignment: Alignment.centerLeft, child: Text("Ações Rápidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary))),
              const SizedBox(height: 10),
              
              _buildMenuOption(
                icon: Icons.history,
                color: Colors.orange,
                title: "Histórico de Treinos Realizados",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutHistoryPage(studentId: user!.uid))),
              ),

              if (isPersonal)
                _buildMenuOption(
                  icon: Icons.library_books,
                  color: Colors.purpleAccent,
                  title: "Gerenciar Biblioteca",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryAdminPage())),
                ),

              _buildMenuOption(
                icon: Icons.logout,
                color: Colors.redAccent,
                title: "Sair da Conta",
                isDestructive: true,
                onTap: () async {
                  await _authService.deslogar();
                  if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Card Estilizado (Sem edição direta, serve como atalho)
  Widget _buildInfoCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.secondary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value, 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({required IconData icon, required Color color, required String title, required VoidCallback onTap, bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
          child: Icon(icon, color: color)
        ),
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
        onTap: onTap,
      ),
    );
  }
}
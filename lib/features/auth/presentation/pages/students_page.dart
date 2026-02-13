import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/user_avatar.dart'; 
import '../../../../core/theme/app_colors.dart'; 
import 'student_detail_page.dart';
import 'chat_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  late TabController _tabController;
  final String _personalId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ENVIAR CONVITE ---
  Future<void> _enviarConvite() async {
    final emailInput = _emailController.text.trim();
    if (emailInput.isEmpty) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Busca o aluno pelo e-mail
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) _mostrarAlerta("Não encontrado", "Não achamos o usuário '$emailInput'.");
        setState(() => _isLoading = false);
        return;
      }

      final alunoDoc = querySnapshot.docs.first;
      final dadosAluno = alunoDoc.data();

      // 2. Validações
      if (alunoDoc.id == user!.uid) {
        _mostrarSnack('Você não pode convidar a si mesmo.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 3. Verifica se já existe convite pendente
      final convitesExistentes = await FirebaseFirestore.instance
          .collection('invites')
          .where('toStudentEmail', isEqualTo: emailInput)
          .where('fromPersonalId', isEqualTo: user.uid)
          .get();

      if (convitesExistentes.docs.isNotEmpty) {
        _mostrarSnack('Já existe um convite pendente para este aluno.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 4. Cria o convite na coleção 'invites'
      await FirebaseFirestore.instance.collection('invites').add({
        'fromPersonalId': user.uid, // Antigo 'personalId'
        'personalId': user.uid, // Novo padrão para NotificationsPage achar
        'personalName': user.displayName ?? 'Personal',
        'toStudentEmail': emailInput,
        'studentUid': alunoDoc.id,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // 5. Cria notificação para o aluno (para acender a bolinha)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(alunoDoc.id)
          .collection('notifications')
          .add({
            'type': 'invite',
            'title': 'Novo Convite de Personal',
            'body': '${user.displayName ?? "Um treinador"} quer te treinar!',
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _mostrarSnack('Convite enviado para ${dadosAluno['name']}! 🚀', isError: false);
        Navigator.pop(context); // Fecha o modal
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Erro ao enviar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE REMOVER ALUNO ---
  Future<void> _removerAluno(String alunoId, String emailAluno) async {
    try {
      // 1. Remove vínculo do usuário
      await FirebaseFirestore.instance.collection('users').doc(alunoId).update({
        'personalId': FieldValue.delete(),
        'personalName': FieldValue.delete(),
        'inviteFromPersonalId': FieldValue.delete(),
      });

      // 2. Remove convites antigos
      final convites = await FirebaseFirestore.instance
          .collection('invites')
          .where('toStudentEmail', isEqualTo: emailAluno)
          .where('personalId', isEqualTo: _personalId)
          .get();

      for (var doc in convites.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        Navigator.pop(context);
        _mostrarSnack('Aluno desvinculado.', isError: false);
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Erro: $e', isError: true);
    }
  }

  // --- LÓGICA DE CANCELAR CONVITE (Aba Pendentes) ---
  Future<void> _cancelarConvite(String inviteId) async {
    try {
      await FirebaseFirestore.instance.collection('invites').doc(inviteId).delete();
      if(mounted) _mostrarSnack('Convite cancelado.');
    } catch (e) {
      if(mounted) _mostrarSnack('Erro: $e', isError: true);
    }
  }

  // --- UI HELPER: DIÁLOGO DE ADICIONAR ---
  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Convidar Aluno", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("O aluno receberá uma notificação para aceitar.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "E-mail do Aluno",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.secondary)),
                prefixIcon: Icon(Icons.email, color: AppColors.secondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarConvite,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
              : const Text("Enviar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarRemocao(String alunoId, String email, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Desvincular Aluno?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja remover $nome?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => _removerAluno(alunoId, email),
            child: const Text("Desvincular", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _mostrarAlerta(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: AppColors.primary)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Meus Alunos", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        // --- ABAS ---
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary, // Neon
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Ativos"),
            Tab(text: "Convites Pendentes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveStudentsList(),
          _buildPendingInvitesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary, // Terracota
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Convidar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }

  // --- LISTA 1: ALUNOS ATIVOS ---
  Widget _buildActiveStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('personalId', isEqualTo: _personalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                const Text("Nenhum aluno ativo.", style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }
        
        final alunos = snapshot.data!.docs;

        return ListView.builder(
          itemCount: alunos.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = alunos[index];
            final dados = doc.data() as Map<String, dynamic>;
            final String nome = dados['name'] ?? 'Aluno';
            final String email = dados['email'] ?? '';

            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.05))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: UserAvatar(photoUrl: dados['photoUrl'], name: nome, radius: 25),
                title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(email, style: const TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => StudentDetailPage(studentId: doc.id, studentName: nome, studentEmail: email),
                  ));
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(otherUserId: doc.id, otherUserName: nome)));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _confirmarRemocao(doc.id, email, nome),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LISTA 2: PENDENTES ---
  Widget _buildPendingInvitesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invites')
          .where('personalId', isEqualTo: _personalId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhum convite pendente.", style: TextStyle(color: Colors.white30)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              color: AppColors.surface.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined, color: AppColors.secondary),
                title: Text(data['toStudentEmail'] ?? "Email desconhecido", style: const TextStyle(color: Colors.white70)),
                subtitle: const Text("Aguardando aceitação...", style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () => _cancelarConvite(doc.id),
                  tooltip: "Cancelar Convite",
                ),
              ),
            );
          },
        );
      },
    );
  }
}
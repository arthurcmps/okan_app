import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/user_avatar.dart'; // Verifique se o caminho está certo
import '../../../../core/theme/app_colors.dart'; // Se tiver tema, se não, use Colors
import 'student_detail_page.dart';
import 'chat_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // --- LÓGICA DE ENVIAR CONVITE (CORRIGIDA) ---
  Future<void> _enviarConvite() async {
    final emailInput = _emailController.text.trim();
    if (emailInput.isEmpty) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Busca o aluno pelo e-mail (Exato)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
           _mostrarAlerta("Não encontrado", "Não achamos o usuário '$emailInput'. Verifique se o e-mail está correto.");
        }
      } else {
        final alunoDoc = querySnapshot.docs.first;
        final dadosAluno = alunoDoc.data();

        // 2. Validações básicas
        if (alunoDoc.id == user!.uid) {
           _mostrarSnack('Você não pode convidar a si mesmo.', isError: true);
           return;
        }

        // Se já tem personal, verifica se é outro
        if (dadosAluno['personalId'] != null && dadosAluno['personalId'] != user.uid) {
           _mostrarSnack('Este usuário já tem outro Personal.', isError: true);
           return;
        }

        if (dadosAluno['personalId'] == user.uid) {
           _mostrarSnack('Este usuário JÁ É seu aluno ativo.', isError: false);
           return;
        }

        // 3. LIMPEZA: Remove convites antigos da coleção 'invites' para não duplicar
        final convitesAntigos = await FirebaseFirestore.instance
            .collection('invites')
            .where('toStudentEmail', isEqualTo: emailInput)
            .where('fromPersonalId', isEqualTo: user.uid)
            .get();
        
        for (var doc in convitesAntigos.docs) {
          await doc.reference.delete();
        }

        // 4. ATUALIZAÇÃO DUPLA (Para garantir compatibilidade)
        
        // A. Atualiza o perfil do aluno (Método antigo/backup)
        // Note que removemos a trava "if inviteFromPersonalId != null". Agora sempre sobrescreve.
        await FirebaseFirestore.instance.collection('users').doc(alunoDoc.id).update({
          'inviteFromPersonalId': user.uid,
          'inviteFromPersonalName': user.displayName ?? 'Personal',
          'inviteStatus': 'pending',
          'inviteDate': FieldValue.serverTimestamp(),
        });

        // B. Cria o documento na coleção 'invites' (Método novo para notificações)
        await FirebaseFirestore.instance.collection('invites').add({
          'fromPersonalId': user.uid,
          'fromPersonalName': user.displayName ?? 'Personal',
          'toStudentEmail': emailInput, // Importante: Salva o e-mail para busca rápida
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _mostrarSnack('Convite enviado para ${dadosAluno['name']}! 🚀', isError: false);
          Navigator.pop(context); // Fecha o modal
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Erro ao enviar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE REMOVER ALUNO (LIMPEZA TOTAL) ---
  Future<void> _removerAluno(String alunoId, String emailAluno) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Remove o vínculo do perfil do aluno
      await FirebaseFirestore.instance.collection('users').doc(alunoId).update({
        'personalId': FieldValue.delete(),
        'personalName': FieldValue.delete(),
        // Limpa também os dados de convite para permitir reenvio limpo
        'inviteFromPersonalId': FieldValue.delete(),
        'inviteFromPersonalName': FieldValue.delete(),
        'inviteStatus': FieldValue.delete(),
      });

      // 2. Remove quaisquer convites (pendentes ou aceitos) da coleção 'invites'
      final convites = await FirebaseFirestore.instance
          .collection('invites')
          .where('toStudentEmail', isEqualTo: emailAluno)
          .where('fromPersonalId', isEqualTo: user.uid)
          .get();

      for (var doc in convites.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        Navigator.pop(context); // Fecha o alerta de confirmação
        _mostrarSnack('Aluno removido e desvinculado.', isError: false);
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Erro ao remover: $e', isError: true);
    }
  }

  // --- UI HELPER: DIÁLOGO DE ADICIONAR ---
  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A273A), // Cor Surface Dark
        title: const Text("Convidar Aluno", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("O aluno receberá uma notificação.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "E-mail do Aluno",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE05D39))), // Terracota
                prefixIcon: Icon(Icons.email, color: Color(0xFFE05D39)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE05D39)),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("Enviar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER: DIÁLOGO DE REMOVER ---
  void _confirmarRemocao(String alunoId, String email, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A273A),
        title: const Text("Desvincular Aluno?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja remover $nome? Ele perderá acesso aos treinos.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => _removerAluno(alunoId, email),
            child: const Text("Desvincular", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  void _mostrarAlerta(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personal = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B2E), // Roxo Dark Okan
      appBar: AppBar(
        title: const Text("Meus Alunos", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('personalId', isEqualTo: personal?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD2F647))); // Neon
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("Você não tem alunos ativos.", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  const Text("Toque em 'Convidar' para começar.", style: TextStyle(color: Colors.white30, fontSize: 12)),
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
              final bool temMensagem = dados['unreadByPersonal'] == true;

              return Card(
                color: const Color(0xFF2A273A), // Surface Dark
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  
                  // FOTO
                  leading: UserAvatar(
                    photoUrl: dados['photoUrl'], 
                    name: nome,
                    radius: 25,
                  ),
                  
                  // INFO
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(email, style: const TextStyle(color: Colors.white70)),
                  
                  // CLIQUE -> DETALHES
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentDetailPage(
                          studentId: doc.id,
                          studentName: nome,
                          studentEmail: email,
                        ),
                      ),
                    );
                  },

                  // AÇÕES (Chat e Deletar)
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.chat_bubble_outline, color: Color(0xFFD2F647)), // Neon
                            if (temMensagem)
                              Positioned(
                                right: 0, top: 0,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(otherUserId: doc.id, otherUserName: nome)));
                        },
                      ),
                      
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmarRemocao(doc.id, email, nome),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE05D39), // Terracota
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Convidar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }
}
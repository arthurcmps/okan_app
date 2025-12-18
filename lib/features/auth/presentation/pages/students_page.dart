import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // --- Lógica de Enviar Convite (Mantida igual) ---
  Future<void> _enviarConvite() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final personal = FirebaseAuth.instance.currentUser;
    final emailBusca = _emailController.text.trim();

    try {
      debugPrint("Buscando usuário: '$emailBusca'...");
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailBusca)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
           showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Não encontrado ❌"),
              content: Text("Não achamos o usuário '$emailBusca'.\n\nDica: Verifique maiúsculas/minúsculas."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            ),
          );
        }
      } else {
        final alunoDoc = querySnapshot.docs.first;
        final dadosAluno = alunoDoc.data();

        if (alunoDoc.id == personal!.uid) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não pode convidar a si mesmo.')));
           setState(() => _isLoading = false);
           return;
        }

        if (dadosAluno['personalId'] != null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este usuário já tem Personal.'), backgroundColor: Colors.orange));
           setState(() => _isLoading = false);
           return;
        }

        if (dadosAluno['inviteFromPersonalId'] != null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Convite já enviado anteriormente.'), backgroundColor: Colors.orange));
           setState(() => _isLoading = false);
           return;
        }

        await FirebaseFirestore.instance.collection('users').doc(alunoDoc.id).update({
          'inviteFromPersonalId': personal.uid,
          'inviteFromPersonalName': personal.displayName ?? 'Personal',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Convite enviado para ${dadosAluno['name']}!'), backgroundColor: Colors.blue),
          );
          Navigator.pop(context);
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Convidar Aluno"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("O aluno receberá uma notificação para aceitar."),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "E-mail do Aluno", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarConvite,
            child: _isLoading ? const CircularProgressIndicator() : const Text("Enviar"),
          ),
        ],
      ),
    );
  }

  // --- Lógica de Desvincular (Agora chamada pelo ícone de lixeira) ---
  void _removerAluno(String alunoId, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Desvincular Aluno?"),
        content: Text("Tem certeza que deseja remover $nome da sua lista?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(alunoId).update({
                'personalId': FieldValue.delete(),
                'personalName': FieldValue.delete(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Desvincular", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personal = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Alunos"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('personalId', isEqualTo: personal?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Você não tem alunos ativos."),
                ],
              ),
            );
          }
          
          final alunos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: alunos.length,
            itemBuilder: (context, index) {
              final doc = alunos[index];
              final dados = doc.data() as Map<String, dynamic>;
              
              final String nome = dados['name'] ?? 'Aluno';
              final String email = dados['email'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  // Ícone ou Foto do Aluno à esquerda
                  leading: CircleAvatar(
                    backgroundColor: Colors.black12,
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  
                  // 1. AÇÃO DE NAVEGAR (Clique Simples)
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

                  // 2. AÇÕES (CHAT + EXCLUIR)
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão Chat
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.teal),
                        tooltip: 'Enviar mensagem',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                otherUserId: doc.id,
                                otherUserName: nome,
                              ),
                            ),
                          );
                        },
                      ),
                      // Botão Excluir
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Desvincular aluno',
                        onPressed: () => _removerAluno(doc.id, nome),
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
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text("Convidar", style: TextStyle(color: Colors.white)),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }
}
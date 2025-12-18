import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // Função para vincular um aluno pelo e-mail
  Future<void> _adicionarAluno() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final personal = FirebaseAuth.instance.currentUser;
    final emailBusca = _emailController.text.trim();

    try {
      // 1. Procura o usuário com esse e-mail
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailBusca)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário não encontrado com este e-mail.'), backgroundColor: Colors.red),
          );
        }
      } else {
        // 2. Se achou, vincula ele a mim (salva meu ID no documento dele)
        final alunoDoc = querySnapshot.docs.first;
        
        // Evita vincular a si mesmo
        if (alunoDoc.id == personal!.uid) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não pode ser seu próprio aluno!')));
           setState(() => _isLoading = false);
           return;
        }

        await FirebaseFirestore.instance.collection('users').doc(alunoDoc.id).update({
          'personalId': personal.uid,
          'personalName': personal.displayName ?? 'Personal',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aluno ${alunoDoc['name']} vinculado com sucesso!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Fecha o diálogo
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Novo Aluno"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Digite o e-mail do usuário que já tem cadastro no App:"),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "E-mail do Aluno",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: _isLoading ? null : _adicionarAluno,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text("Vincular"),
          ),
        ],
      ),
    );
  }

  // Desvincular aluno (opcional, mas bom ter)
  void _removerAluno(String alunoId, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Desvincular Aluno?"),
        content: Text("O usuário $nome deixará de ser seu aluno."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(alunoId).update({
                'personalId': FieldValue.delete(), // Remove o campo
                'personalName': FieldValue.delete(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Desvincular", style: TextStyle(color: Colors.red)),
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
        backgroundColor: Colors.black87, // Estilo mais "Premium/Pro"
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // BUSCA: Usuários que têm o campo 'personalId' igual ao MEU ID
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('personalId', isEqualTo: personal?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Você ainda não tem alunos.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _mostrarDialogoAdicionar,
                    icon: const Icon(Icons.add),
                    label: const Text("Adicionar o primeiro"),
                  )
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
              final nome = dados['name'] ?? 'Aluno';
              final email = dados['email'] ?? '';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.black87,
                    child: Text(nome[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // AQUI VAMOS ABRIR A TELA DE TREINOS DO ALUNO NO FUTURO
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Em breve: Gerenciar treinos de $nome")),
                    );
                  },
                  onLongPress: () => _removerAluno(doc.id, nome),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Novo Aluno", style: TextStyle(color: Colors.white)),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }
}
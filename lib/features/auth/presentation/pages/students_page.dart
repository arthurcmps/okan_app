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

  Future<void> _enviarConvite() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final personal = FirebaseAuth.instance.currentUser;
    final emailBusca = _emailController.text.trim();

    try {
      debugPrint("Buscando usuário: '$emailBusca'...");
      // 1. Procura o usuário
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailBusca)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint("Usuário não encontrado.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail não encontrado.'), backgroundColor: Colors.red));
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Não encontrado ❌"),
              content: Text("Não achamos o usuário '$emailBusca'.\n\nDica: Verifique se o aluno cadastrou o e-mail com letras MAIÚSCULAS ou espaços extras."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            ),
          );
        }
      } else {
        final alunoDoc = querySnapshot.docs.first;
        final dadosAluno = alunoDoc.data();
        debugPrint("Usuário encontrado! Enviando convite...");

        // VALIDAÇÃO 1: Não convidar a si mesmo
        if (alunoDoc.id == personal!.uid) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não pode convidar a si mesmo.')));
           setState(() => _isLoading = false);
           return;
        }

        // VALIDAÇÃO 2: Exclusividade (Já tem personal?)
        if (dadosAluno['personalId'] != null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este usuário já tem um Personal Trainer.'), backgroundColor: Colors.orange));
           setState(() => _isLoading = false);
           return;
        }

        // VALIDAÇÃO 3: Já tem convite pendente?
        if (dadosAluno['inviteFromPersonalId'] != null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este usuário já tem um convite pendente.'), backgroundColor: Colors.orange));
           setState(() => _isLoading = false);
           return;
        }

        // ENVIA O CONVITE (Não vincula ainda, só convida)
        await FirebaseFirestore.instance.collection('users').doc(alunoDoc.id).update({
          'inviteFromPersonalId': personal.uid,
          'inviteFromPersonalName': personal.displayName ?? 'Personal',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Convite enviado para ${dadosAluno['name']}! Aguarde ele aceitar.'), backgroundColor: Colors.blue),
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

  // ... (Restante do código _mostrarDialogoAdicionar e build é igual, só mude a chamada para _enviarConvite)
  
  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Convidar Aluno"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("O aluno receberá uma notificação para aceitar o vínculo."),
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
            onPressed: _isLoading ? null : _enviarConvite, // Chama a nova função
            child: _isLoading ? const CircularProgressIndicator() : const Text("Enviar Convite"),
          ),
        ],
      ),
    );
  }

  // Função para remover aluno (mesma lógica de antes)
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
                'personalId': FieldValue.delete(),
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
      appBar: AppBar(title: const Text("Meus Alunos"), backgroundColor: Colors.black87, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        // AQUI SÓ MOSTRA QUEM JÁ ACEITOU (personalId == eu)
        stream: FirebaseFirestore.instance.collection('users').where('personalId', isEqualTo: personal?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Você não tem alunos ativos."));
          }
          final alunos = snapshot.data!.docs;
          return ListView.builder(
            itemCount: alunos.length,
            itemBuilder: (context, index) {
              final doc = alunos[index];
              final dados = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(dados['name'] ?? 'Aluno'),
                  subtitle: Text(dados['email']),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onLongPress: () => _removerAluno(doc.id, dados['name']),
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
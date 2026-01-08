import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InviteStudentPage extends StatefulWidget {
  const InviteStudentPage({super.key});

  @override
  State<InviteStudentPage> createState() => _InviteStudentPageState();
}

class _InviteStudentPageState extends State<InviteStudentPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _enviarConvite() async {
    if (_emailController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final emailAluno = _emailController.text.trim().toLowerCase();

    try {
      // 1. Verifica se o aluno existe
      final alunoQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailAluno)
          .where('tipo', isEqualTo: 'aluno') // Garante que é aluno
          .get();

      if (alunoQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aluno não encontrado com este e-mail."), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Envia o convite (Cria documento na coleção 'invites')
      await FirebaseFirestore.instance.collection('invites').add({
        'fromPersonalId': user!.uid,
        'fromPersonalName': user.displayName ?? "Seu Personal",
        'toStudentEmail': emailAluno,
        'status': 'pending', // pendente
        'sentAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Convite enviado para $emailAluno!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Convidar Aluno")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "Digite o e-mail do aluno que você quer treinar.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "E-mail do Aluno",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _enviarConvite,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isLoading 
                ? const CircularProgressIndicator() 
                : const Text("ENVIAR CONVITE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _aceitarConvite(BuildContext context, String inviteId, String personalId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Vincula o aluno ao personal (Atualiza o perfil do aluno)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'personalId': personalId,
      });

      // 2. Marca o convite como aceito (ou deleta)
      await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
        'status': 'accepted',
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Convite aceito! Agora você está vinculado."), backgroundColor: Colors.green));
      Navigator.pop(context); // Volta pra Home atualizada
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao aceitar: $e")));
    }
  }

  Future<void> _recusarConvite(String inviteId) async {
    await FirebaseFirestore.instance.collection('invites').doc(inviteId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Notificações")),
      body: StreamBuilder<QuerySnapshot>(
        // Busca convites onde o e-mail de destino é o meu e o status é pendente
        stream: FirebaseFirestore.instance
            .collection('invites')
            .where('toStudentEmail', isEqualTo: user?.email)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final convites = snapshot.data!.docs;

          if (convites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Nenhuma notificação nova."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: convites.length,
            itemBuilder: (context, index) {
              final convite = convites[index];
              final data = convite.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Convite de ${data['fromPersonalName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("Este personal quer adicionar você à lista de alunos."),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _recusarConvite(convite.id),
                            child: const Text("RECUSAR", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _aceitarConvite(context, convite.id, data['fromPersonalId']),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text("ACEITAR"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
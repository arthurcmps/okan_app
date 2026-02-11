import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; 

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _aceitarConvite(BuildContext context, String inviteId, String personalId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Vincula o aluno ao personal
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'personalId': personalId,
        'hasPersonal': true, 
      });

      // 2. Atualiza o status do convite
      await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
        'status': 'accepted',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Convite aceito! 🔥"), backgroundColor: AppColors.secondary),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Future<void> _recusarConvite(String inviteId) async {
    await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
      'status': 'rejected'
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user?.email == null) {
      return const Scaffold(body: Center(child: Text("Erro: Usuário sem e-mail.")));
    }

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: const Text("Notificações", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invites')
            .where('toStudentEmail', isEqualTo: user!.email) // Certifique-se que o email bate
            .where('status', isEqualTo: 'pending')
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
                  Icon(Icons.notifications_none, size: 80, color: AppColors.textSub.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("Tudo limpo por aqui.", style: TextStyle(color: AppColors.textSub)),
                ],
              ),
            );
          }

          final convites = snapshot.data!.docs;

          return ListView.builder(
            itemCount: convites.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final convite = convites[index];
              final data = convite.data() as Map<String, dynamic>;
              
              final nomePersonal = data['fromPersonalName'] ?? 'Personal';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface, 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add, color: AppColors.secondary),
                        const SizedBox(width: 10),
                        const Text("Convite de Treino", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$nomePersonal quer ser seu treinador no Okan.", 
                      style: const TextStyle(color: Colors.white, fontSize: 16)
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _recusarConvite(convite.id),
                          child: const Text("Recusar", style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        
                        ElevatedButton(
                          onPressed: () => _aceitarConvite(context, convite.id, data['fromPersonalId']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, 
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("ACEITAR CONVITE"),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import 'chat_page.dart';
import 'weekly_plan_page.dart';
import 'assessments_tab.dart'; 
// Importe a StudentDetailPage se precisar redirecionar para lá, ou use rotas nomeadas.

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("Não logado")));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Notificações", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Botão para "Marcar todas como lidas" (Futura implementação)
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.textSub),
            onPressed: () => _marcarTodasComoLidas(user.uid),
            tooltip: "Marcar todas como lidas",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEÇÃO 1: CONVITES (Alta Prioridade) ---
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text("CONVITES PENDENTES", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
            _buildInvitesStream(user),

            const SizedBox(height: 24),

            // --- SEÇÃO 2: ATIVIDADES RECENTES (Mensagens, Treinos, etc) ---
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text("RECENTES", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
            _buildGeneralNotificationsStream(context, user),
          ],
        ),
      ),
    );
  }

  // --- STREAM DE CONVITES (Mantendo sua lógica original) ---
  Widget _buildInvitesStream(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invites')
          .where('toStudentEmail', isEqualTo: user.email)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Nenhum convite pendente.");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final personalName = data['personalName'] ?? 'Personal';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)), // Borda Neon para destaque
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person_add, color: Colors.black)),
                    title: Text(personalName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Quer ser seu treinador no Okan", style: TextStyle(color: Colors.white70)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _responderConvite(context, doc.id, false),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                            child: const Text("Recusar", style: TextStyle(color: AppColors.error)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _responderConvite(context, doc.id, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            child: const Text("Aceitar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- STREAM DE NOTIFICAÇÕES GERAIS (Mensagens, Treinos, Avaliações) ---
  Widget _buildGeneralNotificationsStream(BuildContext context, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications') // <--- Nova Subcoleção
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Nenhuma notificação recente.");
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool isRead = data['isRead'] ?? false;

            return Dismissible(
              key: Key(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: AppColors.error,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                doc.reference.delete();
              },
              child: GestureDetector(
                onTap: () {
                  _handleNotificationTap(context, doc, data);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? AppColors.surface.withOpacity(0.5) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: isRead ? null : Border(left: BorderSide(color: _getColorByType(data['type']), width: 4)),
                  ),
                  child: Row(
                    children: [
                      _getIconByType(data['type']),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'Notificação',
                              style: TextStyle(
                                color: isRead ? Colors.white54 : Colors.white,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 15
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['body'] ?? '',
                              style: const TextStyle(color: AppColors.textSub, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(data['timestamp']),
                              style: TextStyle(color: Colors.white30, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _getColorByType(data['type']), shape: BoxShape.circle),
                        )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LÓGICA DE AÇÃO ---
  void _handleNotificationTap(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) async {
    // 1. Marca como lida
    if (data['isRead'] == false) {
      await doc.reference.update({'isRead': true});
    }

    // 2. Navega baseado no tipo
    if (!context.mounted) return;
    
    switch (data['type']) {
      case 'message':
        // ActionId deve ser o ID do usuário que mandou a mensagem
        Navigator.push(context, MaterialPageRoute(builder: (context) => 
          ChatPage(otherUserId: data['actionId'], otherUserName: data['senderName'] ?? 'Chat')
        ));
        break;
        
      case 'workout':
        Navigator.push(context, MaterialPageRoute(builder: (context) => 
          // Ajuste conforme sua navegação
          WeeklyPlanPage(studentId: FirebaseAuth.instance.currentUser!.uid, studentName: "Meus Treinos")
        ));
        break;

      case 'assessment':
        // Pode ir para a tab de avaliações (exige um pequeno refactor na ProfilePage para abrir direto na tab, mas por enquanto abrimos o perfil)
        // O ideal aqui seria uma Page separada só de Detalhes da Avaliação.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vá em Perfil > Avaliações para ver os detalhes.")));
        break;
    }
  }

  // --- HELPERS VISUAIS ---
  Color _getColorByType(String? type) {
    switch (type) {
      case 'message': return Colors.blueAccent;
      case 'workout': return AppColors.primary; // Neon
      case 'assessment': return AppColors.secondary; // Terracota
      default: return Colors.grey;
    }
  }

  Widget _getIconByType(String? type) {
    IconData icon;
    Color color = _getColorByType(type);
    
    switch (type) {
      case 'message': icon = Icons.chat_bubble; break;
      case 'workout': icon = Icons.fitness_center; break;
      case 'assessment': icon = Icons.monitor_weight; break;
      default: icon = Icons.notifications;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} min atrás";
    if (diff.inHours < 24) return "${diff.inHours}h atrás";
    return DateFormat('dd/MM').format(date);
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white30)),
    );
  }

  // --- LÓGICA DE CONVITE (Mantida) ---
  Future<void> _responderConvite(BuildContext context, String inviteId, bool aceitar) async {
    try {
      final inviteDoc = await FirebaseFirestore.instance.collection('invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;

      final data = inviteDoc.data()!;
      final studentId = FirebaseAuth.instance.currentUser!.uid;
      final personalId = data['personalId'];
      final personalName = data['personalName'];

      if (aceitar) {
        // Vincula no documento do aluno
        await FirebaseFirestore.instance.collection('users').doc(studentId).update({
          'personalId': personalId,
          'personalName': personalName,
          'inviteFromPersonalId': inviteId,
        });
        
        // (Opcional) Adiciona o aluno na lista do personal se tiver uma collection 'students' lá
        // Mas no seu modelo atual parece que você busca por query "users where personalId == meuId", então tá ok.
      }

      // Atualiza status do convite
      await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
        'status': aceitar ? 'accepted' : 'rejected',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(aceitar ? "Convite aceito! Agora vocês estão conectados." : "Convite recusado."),
          backgroundColor: aceitar ? AppColors.success : Colors.grey,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }
  
  Future<void> _marcarTodasComoLidas(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').where('isRead', isEqualTo: false).get();
    
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
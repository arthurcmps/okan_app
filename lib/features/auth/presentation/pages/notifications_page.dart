import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import 'chat_page.dart';
import 'weekly_plan_page.dart';
import 'assessments_tab.dart'; 
import 'student_detail_page.dart'; 

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

  // --- STREAM DE CONVITES ---
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
            final personalName = data['personalName'] ?? data['fromPersonalName'] ?? 'Personal';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)), 
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

  // --- STREAM DE NOTIFICAÇÕES GERAIS ---
  Widget _buildGeneralNotificationsStream(BuildContext context, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
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
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    border: isRead ? null : Border(left: BorderSide(color: _getColorByData(data), width: 4)),
                  ),
                  child: Row(
                    children: [
                      _getIconByData(data),
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
                              style: const TextStyle(color: Colors.white30, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _getColorByData(data), shape: BoxShape.circle),
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

  // --- LÓGICA DE NAVEGAÇÃO E AÇÃO ---
  void _handleNotificationTap(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) async {
    // 1. Marca como lida
    if (data['isRead'] == false) {
      await doc.reference.update({'isRead': true});
    }

    if (!context.mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    switch (data['type']) {
      case 'invite': 
        final inviteId = data['actionId'];
        if (inviteId != null && inviteId.toString().isNotEmpty) {
          _mostrarDialogoConvite(context, inviteId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Olhe no topo da tela, nos seus convites pendentes!")));
        }
        break;

      case 'message':
        Navigator.push(context, MaterialPageRoute(builder: (context) => 
          ChatPage(otherUserId: data['actionId'], otherUserName: data['senderName'] ?? 'Chat')
        ));
        break;
        
      case 'workout':
      case 'workout_update':
        final actionId = data['actionId'] ?? currentUser.uid;

        // Se a notificação for de OUTRO usuário, significa que você é o Personal abrindo o aviso do Aluno
        if (actionId != currentUser.uid) {
          final studentDoc = await FirebaseFirestore.instance.collection('users').doc(actionId).get();
          final studentData = studentDoc.data() ?? {};
          
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => 
              StudentDetailPage(
                studentId: actionId, 
                studentName: studentData['name'] ?? studentData['nome'] ?? 'Aluno', 
                studentEmail: studentData['email'] ?? ''
              )
            ));
          }
        } else {
          // Se for você mesmo (Aluno a ver a própria ficha atualizada)
          Navigator.push(context, MaterialPageRoute(builder: (context) => 
            WeeklyPlanPage(studentId: currentUser.uid, studentName: "Meus Treinos")
          ));
        }
        break;

      case 'assessment':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vá em Perfil > Avaliações para ver os detalhes.")));
        break;
    }
  }

  // --- POP-UP DE CONVITE DIRETO DA LISTA ---
  Future<void> _mostrarDialogoConvite(BuildContext context, String inviteId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('invites').doc(inviteId).get();
      if (!context.mounted) return;
      
      if (!doc.exists || doc.data()!['status'] != 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este convite já foi respondido ou não está mais disponível.", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white));
        return;
      }
      
      final data = doc.data()!;
      final personalName = data['personalName'] ?? data['fromPersonalName'] ?? 'Personal';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Convite Pendente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text("$personalName quer ser o seu treinador no Okan.", style: const TextStyle(color: Colors.white70)),
          actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(ctx);
                 _responderConvite(context, inviteId, false);
               },
               child: const Text("Recusar", style: TextStyle(color: AppColors.error)),
             ),
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
               onPressed: () {
                 Navigator.pop(ctx);
                 _responderConvite(context, inviteId, true);
               },
               child: const Text("Aceitar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
             ),
          ]
        )
      );
    } catch(e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  // --- HELPERS VISUAIS DINÂMICOS (CORES E ÍCONES) ---
  Color _getColorByData(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().toLowerCase();
    final type = data['type'];

    // Lógica inteligente baseada no título (Para alertas automáticos)
    if (title.contains('vencido')) return Colors.redAccent;
    if (title.contains('vencendo') || title.contains('alteração')) return Colors.amber;
    if (title.contains('feedback')) return Colors.blueAccent;

    // Lógica padrão baseada no tipo
    switch (type) {
      case 'message': return Colors.blueAccent;
      case 'workout': 
      case 'workout_update': return AppColors.primary; 
      case 'assessment': return AppColors.secondary; 
      case 'invite': return Colors.amber; 
      default: return Colors.grey;
    }
  }

  Widget _getIconByData(Map<String, dynamic> data) {
    IconData icon;
    Color color = _getColorByData(data);
    
    final title = (data['title'] ?? '').toString().toLowerCase();
    final type = data['type'];

    // Ícones personalizados para os alertas automáticos
    if (title.contains('vencido')) {
      icon = Icons.warning_amber_rounded;
    } else if (title.contains('vencendo')) {
      icon = Icons.timer_outlined;
    } else if (title.contains('alteração')) {
      icon = Icons.change_circle_outlined;
    } else if (title.contains('feedback')) {
      icon = Icons.feedback_outlined;
    } else {
      // Ícones padrão
      switch (type) {
        case 'message': icon = Icons.chat_bubble; break;
        case 'workout': 
        case 'workout_update': icon = Icons.fitness_center; break;
        case 'assessment': icon = Icons.monitor_weight; break;
        case 'invite': icon = Icons.person_add; break;
        default: icon = Icons.notifications;
      }
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

  // --- LÓGICA DE RESPOSTA DO CONVITE ---
  Future<void> _responderConvite(BuildContext context, String inviteId, bool aceitar) async {
    try {
      final inviteDoc = await FirebaseFirestore.instance.collection('invites').doc(inviteId).get();
      if (!inviteDoc.exists) return;

      final data = inviteDoc.data()!;
      final studentId = FirebaseAuth.instance.currentUser!.uid;
      final personalId = data['personalId'] ?? data['fromPersonalId'];
      final personalName = data['personalName'] ?? data['fromPersonalName'];

      if (aceitar) {
        await FirebaseFirestore.instance.collection('users').doc(studentId).update({
          'personalId': personalId,
          'personalName': personalName,
          'inviteFromPersonalId': inviteId,
        });
      }

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
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart';

// Imports das suas páginas
import 'train_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'dashboard_chart.dart';
import 'students_page.dart';
import 'chat_page.dart'; // <--- IMPORTANTE: Importe o Chat

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controladores para criar treino
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  // --- FUNÇÕES DE CONVITE (Lógica de aceitar/recusar vínculo) ---
  Future<void> _responderConvite(String personalId, String personalName, bool aceitar) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (aceitar) {
        // Aceitou: Define o personalId e limpa o convite
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'personalId': personalId,
          'personalName': personalName,
          'inviteFromPersonalId': FieldValue.delete(),
          'inviteFromPersonalName': FieldValue.delete(),
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Convite aceito! 🤝"), backgroundColor: Colors.green));
      } else {
        // Recusou: Apenas limpa o convite
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'inviteFromPersonalId': FieldValue.delete(),
          'inviteFromPersonalName': FieldValue.delete(),
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Convite recusado.")));
      }
    } catch (e) {
      debugPrint("Erro ao responder convite: $e");
    }
  }

  void _mostrarDialogoConvite(String personalId, String personalName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Convite de Personal 🏋️"),
        content: Text("$personalName quer ser seu treinador.\nAceitar vínculo?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _responderConvite(personalId, personalName, false);
            },
            child: const Text("Recusar", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _responderConvite(personalId, personalName, true);
            },
            child: const Text("Aceitar"),
          ),
        ],
      ),
    );
  }
  // ---------------------------------

  void _mostrarDialogoCriar() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Novo Treino"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome (ex: Treino A)"),
              ),
              TextField(
                controller: _grupoController,
                decoration: const InputDecoration(labelText: "Foco (ex: Peito/Tríceps)"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return; 

                await FirebaseFirestore.instance.collection('treinos').add({
                  'userId': user.uid,
                  'nome': _nomeController.text.isNotEmpty ? _nomeController.text : 'Treino Novo',
                  'grupo': _grupoController.text.isNotEmpty ? _grupoController.text : 'Geral',
                  'qtd_exercicios': 0,
                  'duracao': '?? min',
                  'criadoEm': FieldValue.serverTimestamp(),
                });

                _nomeController.clear();
                _grupoController.clear();

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Criar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fazerLogout() async {
    try {
      try { await GoogleSignIn().signOut(); } catch (e) { debugPrint("Erro Google: $e"); }
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao sair: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user?.displayName ?? "Atleta";

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${nomeUsuario.split(' ')[0]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Bora treinar?', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              
              final dados = snapshot.data!.data() as Map<String, dynamic>;
              
              // Verifica convite
              final temConvite = dados.containsKey('inviteFromPersonalId') && dados['inviteFromPersonalId'] != null;
              
              // Verifica Personal
              final personalId = dados['personalId'];
              final personalName = dados['personalName'];
              final temPersonal = personalId != null && personalId.toString().isNotEmpty;

              // --- NOVA LÓGICA DE NOTIFICAÇÃO ---
              final bool temMensagemNaoLida = dados['unreadByStudent'] == true;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ÍCONE DE CHAT COM BOLINHA
                  if (temPersonal)
                    IconButton(
                      icon: Stack(
                        children: [
                          const Icon(Icons.chat, color: Colors.teal),
                          if (temMensagemNaoLida) // <--- MOSTRA A BOLINHA
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                              ),
                            )
                        ],
                      ),
                      tooltip: 'Falar com Personal',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              otherUserId: personalId,
                              otherUserName: personalName ?? 'Personal',
                              studentId: user!.uid, // <--- Sou o aluno, passo meu ID
                            ),
                          ),
                        );
                      },
                    ),

                  // 2. ÍCONE DE NOTIFICAÇÃO (Se tiver Convite)
                  if (temConvite)
                    IconButton(
                      icon: Stack(
                        children: [
                          const Icon(Icons.notifications, color: Colors.black87, size: 28),
                          Positioned(
                            right: 0, top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                            ),
                          )
                        ],
                      ),
                      tooltip: 'Convite pendente',
                      onPressed: () => _mostrarDialogoConvite(dados['inviteFromPersonalId'], dados['inviteFromPersonalName']),
                    ),
                ],
              );
            },
          ),
          
          // Botão Maleta (Área do Personal)
          IconButton(
            icon: const Icon(Icons.work, color: Colors.black87),
            tooltip: 'Área do Personal',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentsPage())),
          ),
          
          // Botão Perfil
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu Perfil',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
          ),
          
          // Botão Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sair',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardChart(),
            const SizedBox(height: 24),

            const Text('Seus Treinos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('treinos')
                    .where('userId', isEqualTo: user?.uid) 
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final dados = snapshot.data?.docs;
                  
                  if (dados == null || dados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Nenhum treino encontrado.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: dados.length,
                    itemBuilder: (context, index) {
                      final treino = dados[index].data() as Map<String, dynamic>;
                      final nome = treino['nome']?.toString() ?? 'Sem nome';
                      final grupo = treino['grupo']?.toString() ?? 'Geral';
                      final qtd = treino['qtd_exercicios']?.toString() ?? '0';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => TreinoDetalhesPage(nomeTreino: nome, grupoMuscular: grupo, treinoId: dados[index].id)));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : "T", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(grupo, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.fitness_center, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text("$qtd exercícios", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _mostrarDialogoCriar,
      ),
    );
  }
}
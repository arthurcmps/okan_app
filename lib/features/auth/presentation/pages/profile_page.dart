import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
      ),
      body: Column(
        children: [
          // Cabeçalho do Perfil
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue,
                  child: Text(
                    user?.displayName?.substring(0, 1).toUpperCase() ?? "A",
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? "Atleta",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? "",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Histórico de Treinos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // LISTA DE HISTÓRICO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('historico')
                  .where('usuarioId', isEqualTo: user?.uid) // Filtra SÓ o seu usuário
                  .orderBy('data', descending: true) // Ordena do mais recente para o antigo
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Erro ao carregar histórico."));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Você ainda não completou nenhum treino."),
                  );
                }

                final historico = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: historico.length,
                  itemBuilder: (context, index) {
                    final dados = historico[index].data() as Map<String, dynamic>;
                    
                    final nomeTreino = dados['treinoNome'] ?? 'Treino';
                    
                    // Tratamento de Data (Timestamp do Firebase para Texto)
                    final Timestamp? timestamp = dados['data'];
                    final DateTime data = timestamp?.toDate() ?? DateTime.now();
                    final dataFormatada = "${data.day}/${data.month}/${data.year} às ${data.hour}:${data.minute.toString().padLeft(2, '0')}";

                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(nomeTreino, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(dataFormatada),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageWorkoutsPage extends StatelessWidget {
  const ManageWorkoutsPage({super.key});

  void _deletarTreino(BuildContext context, String treinoId, String nomeTreino) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Treino?"),
        content: Text("Tem certeza que deseja apagar '$nomeTreino'? Isso não remove o treino do histórico dos alunos que já o realizaram."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('workouts').doc(treinoId).delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino excluído.")));
              }
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _verDetalhesTreino(BuildContext context, Map<String, dynamic> dados) {
    final exercicios = List<Map<String, dynamic>>.from(dados['exercicios'] ?? []);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(dados['nome'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: exercicios.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (context, index) {
                      final ex = exercicios[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(ex['nome']),
                        subtitle: Text("${ex['series']}x ${ex['repeticoes']}"),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Meus Modelos de Treino")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .orderBy('criadoEm', descending: true)
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
                  Icon(Icons.fitness_center, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Nenhum modelo de treino criado."),
                ],
              ),
            );
          }

          final treinos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: treinos.length,
            itemBuilder: (context, index) {
              final doc = treinos[index];
              final data = doc.data() as Map<String, dynamic>;
              final qtdExercicios = (data['exercicios'] as List?)?.length ?? 0;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.assignment_outlined, color: Colors.purple),
                  ),
                  title: Text(data['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['grupoMuscular'] ?? 'Geral'} • $qtdExercicios exercícios"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deletarTreino(context, doc.id, data['nome']),
                  ),
                  onTap: () => _verDetalhesTreino(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_workout_page.dart'; // <--- Importante para navegar

class ManageWorkoutsPage extends StatelessWidget {
  const ManageWorkoutsPage({super.key});

  void _deletarTreino(BuildContext context, String treinoId, String nomeTreino) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Treino?"),
        content: Text("Tem certeza que deseja apagar '$nomeTreino'?"),
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

  void _editarTreino(BuildContext context, String id, Map<String, dynamic> dados) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWorkoutPage(
          treinoId: id,       // Passa o ID para ativar modo edição
          treinoDados: dados, // Passa os dados para preencher a tela
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Meus Modelos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workouts')
            .orderBy('criadoEm', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum modelo criado."));
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1), 
                    child: const Icon(Icons.fitness_center, color: Colors.teal)
                  ),
                  title: Text(data['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['grupoMuscular'] ?? 'Geral'} • $qtdExercicios exercícios"),
                  
                  // AQUI ESTÃO OS BOTÕES DE AÇÃO
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão Editar
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editarTreino(context, doc.id, data),
                      ),
                      // Botão Excluir
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletarTreino(context, doc.id, data['nome']),
                      ),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({super.key});

  @override
  State<LibraryAdminPage> createState() => _LibraryAdminPageState();
}

class _LibraryAdminPageState extends State<LibraryAdminPage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  void _mostrarDialogo({DocumentSnapshot? doc}) {
    // Se tiver doc, é EDIÇÃO. Se for null, é CRIAÇÃO.
    final bool isEditando = doc != null;

    if (isEditando) {
      _nomeController.text = doc['nome'];
      _videoController.text = doc['video']; // ou 'videoUrl' dependendo de como salvou antes
      _grupoController.text = doc['grupo'] ?? '';
    } else {
      _nomeController.clear();
      _videoController.clear();
      _grupoController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditando ? "Editar Exercício" : "Novo Exercício"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: "Nome do Exercício"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _grupoController,
                  decoration: const InputDecoration(labelText: "Grupo Muscular (ex: Peito)"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _videoController,
                  decoration: const InputDecoration(
                    labelText: "Link do Vídeo (YouTube)",
                    hintText: "https://youtu.be/...",
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nomeController.text.isEmpty) return;

                final data = {
                  'nome': _nomeController.text.trim(),
                  'grupo': _grupoController.text.trim(),
                  'video': _videoController.text.trim(),
                };

                try {
                  if (isEditando) {
                    await FirebaseFirestore.instance.collection('library').doc(doc.id).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('library').add(data);
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  void _deletarExercicio(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tem certeza?"),
        content: const Text("Isso apagará o exercício da biblioteca para todos."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('library').doc(id).delete();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Apagar", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar Biblioteca"),
        backgroundColor: Colors.purple, // Cor diferente para indicar área "Admin"
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('library').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Biblioteca vazia."));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.purple),
                title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['grupo'] ?? 'Geral'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão Editar
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _mostrarDialogo(doc: doc),
                    ),
                    // Botão Excluir
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletarExercicio(doc.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _mostrarDialogo(),
      ),
    );
  }
}
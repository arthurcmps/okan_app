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

  // CORREÇÃO: Mudamos para 'exercises' para alinhar com a tela de criar treino
  final CollectionReference _exercisesCollection = 
      FirebaseFirestore.instance.collection('exercises'); 

  void _mostrarDialogo({DocumentSnapshot? doc}) {
    final bool isEditando = doc != null;

    if (isEditando) {
      _nomeController.text = doc['nome'];
      // Lógica para suportar o nome antigo ('video') ou novo ('videoUrl')
      final data = doc.data() as Map<String, dynamic>;
      _videoController.text = data['videoUrl'] ?? data['video'] ?? '';
      _grupoController.text = data['grupo'] ?? '';
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
                TextField(controller: _nomeController, decoration: const InputDecoration(labelText: "Nome do Exercício")),
                const SizedBox(height: 8),
                TextField(controller: _grupoController, decoration: const InputDecoration(labelText: "Grupo Muscular")),
                const SizedBox(height: 8),
                TextField(controller: _videoController, decoration: const InputDecoration(labelText: "Link do Vídeo (YouTube)", icon: Icon(Icons.link))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (_nomeController.text.isEmpty) return;
                
                final data = {
                  'nome': _nomeController.text.trim(),
                  'grupo': _grupoController.text.trim(),
                  'videoUrl': _videoController.text.trim(), // Salvando como videoUrl
                  'criadoEm': FieldValue.serverTimestamp(),
                };

                try {
                  if (isEditando) {
                    await _exercisesCollection.doc(doc.id).update(data);
                  } else {
                    await _exercisesCollection.add(data);
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
    _exercisesCollection.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Biblioteca"), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: _exercisesCollection.orderBy('nome').snapshots(), // Busca de 'exercises'
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Biblioteca vazia. Adicione exercícios pelo +"));
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
                trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarDialogo(doc: doc)),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'train_page.dart';
import 'profile_page.dart';

class StudentDetailPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  // Função para criar treino PARA O ALUNO
  void _mostrarDialogoCriarParaAluno() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Treino para ${widget.studentName.split(' ')[0]}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome (ex: Hipertrofia A)"),
              ),
              TextField(
                controller: _grupoController,
                decoration: const InputDecoration(labelText: "Foco (ex: Pernas)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                // AQUI ESTÁ O SEGREDO:
                // Salvamos o treino com o userId DO ALUNO, não o meu.
                await FirebaseFirestore.instance.collection('treinos').add({
                  'userId': widget.studentId, // <--- ID do Aluno
                  'personalId': 'EU', // Opcional: para saber quem criou
                  'nome': _nomeController.text.isNotEmpty ? _nomeController.text : 'Novo Treino',
                  'grupo': _grupoController.text.isNotEmpty ? _grupoController.text : 'Geral',
                  'qtd_exercicios': 0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.studentName, style: const TextStyle(fontSize: 16)),
            Text(widget.studentEmail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Ver Perfil do Aluno',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(userId: widget.studentId), // Passamos o ID dele!
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho Simples
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.grey.shade200,
            child: const Text("Fichas de Treino Ativas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          // LISTA DE TREINOS DO ALUNO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // FILTRO: Traz apenas treinos onde userId == ID DO ALUNO
              stream: FirebaseFirestore.instance
                  .collection('treinos')
                  .where('userId', isEqualTo: widget.studentId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text("${widget.studentName} não tem treinos ainda."),
                      ],
                    ),
                  );
                }

                final dados = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dados.length,
                  itemBuilder: (context, index) {
                    final treino = dados[index].data() as Map<String, dynamic>;
                    final nome = treino['nome'] ?? 'Sem nome';
                    final grupo = treino['grupo'] ?? 'Geral';
                    final qtd = treino['qtd_exercicios'] ?? 0;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(nome[0].toUpperCase(), style: const TextStyle(color: Colors.blue)),
                        ),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("$grupo • $qtd exercícios"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Abre a mesma tela de detalhes que já criamos
                          // Como ela lê o banco pelo ID do treino, funciona igual!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TreinoDetalhesPage(
                                nomeTreino: nome,
                                grupoMuscular: grupo,
                                treinoId: dados[index].id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Novo Treino", style: TextStyle(color: Colors.white)),
        onPressed: _mostrarDialogoCriarParaAluno,
      ),
    );
  }
}
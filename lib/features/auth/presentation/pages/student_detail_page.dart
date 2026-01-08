import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart'; // Importante para o botão de Chat

class StudentDetailPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  // Função para abrir o modal e escolher um treino da coleção 'workouts'
  void _atribuirTreino(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16), 
              child: Text("Selecione um Treino para Atribuir", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('workouts').orderBy('criadoEm', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum treino criado ainda. Vá em 'Criar Novo Treino'."));

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final treino = snapshot.data!.docs[index];
                      final dadosTreino = treino.data() as Map<String, dynamic>;

                      return ListTile(
                        leading: const Icon(Icons.fitness_center, color: Colors.blue),
                        title: Text(dadosTreino['nome'] ?? 'Sem nome'),
                        subtitle: Text(dadosTreino['grupoMuscular'] ?? ''),
                        onTap: () async {
                          // SALVA O ID E NOME DO TREINO NO PERFIL DO ALUNO
                          await FirebaseFirestore.instance.collection('users').doc(studentId).update({
                            'currentWorkoutId': treino.id,
                            'currentWorkoutName': dadosTreino['nome'], 
                          });
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Treino '${dadosTreino['nome']}' atribuído com sucesso!"))
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(studentName)),
      
      // BOTÃO FLUTUANTE PARA CHAT
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          // Navega para o chat passando os dados deste aluno
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(
            otherUserId: studentId,
            otherUserName: studentName,
          )));
        },
      ),

      body: Column(
        children: [
          // CABEÇALHO COM DADOS DO ALUNO
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Column(
              children: [
                CircleAvatar(radius: 35, backgroundColor: Colors.blue, child: Text(studentName[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.white))),
                const SizedBox(height: 10),
                Text(studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(studentEmail, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 20),
                
                // CARD DO TREINO ATUAL
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
                  builder: (context, snapshot) {
                    String treinoAtual = "Nenhum treino definido";
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      treinoAtual = data['currentWorkoutName'] ?? "Nenhum treino definido";
                    }

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.run_circle_outlined, color: Colors.orange, size: 30),
                        title: const Text("Treino Atual", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(treinoAtual, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: ElevatedButton(
                          onPressed: () => _atribuirTreino(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: const Text("Alterar"),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text("Histórico de Execuções", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ),

          // LISTA DE HISTÓRICO DE TREINOS FEITOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('historico')
                  .where('usuarioId', isEqualTo: studentId)
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("O aluno ainda não completou nenhum treino."));

                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_,__) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final treino = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final data = (treino['data'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final qtdExercicios = treino['exerciciosConcluidos'] ?? 0;

                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(treino['treinoNome'] ?? 'Treino'),
                      subtitle: Text(DateFormat("dd/MM/yyyy 'às' HH:mm").format(data)),
                      trailing: Text("$qtdExercicios concluídos", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
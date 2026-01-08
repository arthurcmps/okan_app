import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

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

  final Map<int, String> _diasSemana = const {
    1: "Segunda-feira",
    2: "Terça-feira",
    3: "Quarta-feira",
    4: "Quinta-feira",
    5: "Sexta-feira",
    6: "Sábado",
    7: "Domingo",
  };

  void _definirTreinoParaDia(BuildContext context, int diaSemana) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16), 
              child: Text("Agenda de ${_diasSemana[diaSemana]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ),
            
            ListTile(
              leading: const Icon(Icons.hotel, color: Colors.green),
              title: const Text("Definir como Descanso"),
              onTap: () async {
                await FirebaseFirestore.instance.collection('users').doc(studentId).set({
                  'weeklyWorkouts': {
                    diaSemana.toString(): { 'id': 'rest', 'name': 'Descanso' }
                  }
                }, SetOptions(merge: true));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Limpar dia (Sem treino)"),
              onTap: () async {
                await FirebaseFirestore.instance.collection('users').doc(studentId).update({
                  'weeklyWorkouts.$diaSemana': FieldValue.delete()
                });
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const Divider(),
            const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("Selecionar Modelo de Treino:", style: TextStyle(color: Colors.grey)))),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('workouts').orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum treino criado."));

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
                          await FirebaseFirestore.instance.collection('users').doc(studentId).set({
                            'weeklyWorkouts': {
                              diaSemana.toString(): {
                                'id': treino.id,
                                'name': dadosTreino['nome']
                              }
                            }
                          }, SetOptions(merge: true));
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Agendado: ${dadosTreino['nome']}")));
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
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(
            otherUserId: studentId,
            otherUserName: studentName,
          )));
        },
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Colors.blue, child: Text(studentName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white))),
                  const SizedBox(height: 10),
                  Text(studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(studentEmail, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text("Cronograma Semanal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
              builder: (context, snapshot) {
                Map<String, dynamic> weeklyWorkouts = {};
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  weeklyWorkouts = data['weeklyWorkouts'] != null ? Map<String, dynamic>.from(data['weeklyWorkouts']) : {};
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final diaNum = index + 1;
                    final dadosDia = weeklyWorkouts[diaNum.toString()];
                    
                    String nomeTreino = "Toque para definir";
                    Color corFundo = Colors.transparent;
                    IconData icone = Icons.add_circle_outline;
                    Color corIcone = Colors.grey;

                    if (dadosDia != null) {
                      if (dadosDia['id'] == 'rest') {
                        nomeTreino = "Descanso";
                        corFundo = Colors.green.shade50;
                        icone = Icons.hotel;
                        corIcone = Colors.green;
                      } else {
                        nomeTreino = dadosDia['name'] ?? "Treino";
                        corFundo = Colors.blue.shade50; // Destaque suave
                        icone = Icons.fitness_center;
                        corIcone = Colors.blue;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: dadosDia != null ? 1 : 0,
                      color: dadosDia != null ? Colors.white : Colors.grey.shade50,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: corFundo.withOpacity(0.3), // Aplica cor de fundo se houver
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(icone, color: corIcone, size: 20),
                          ),
                          title: Text(_diasSemana[diaNum]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(nomeTreino, style: TextStyle(color: dadosDia != null ? Colors.black87 : Colors.grey)),
                          trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onTap: () => _definirTreinoParaDia(context, diaNum),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text("Histórico Recente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('historico')
                  .where('usuarioId', isEqualTo: studentId)
                  .orderBy('data', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(16), child: Text("Sem histórico recente."));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final treino = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final data = (treino['data'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: Text(treino['treinoNome'] ?? 'Treino'),
                      trailing: Text(DateFormat("dd/MM - HH:mm").format(data)),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
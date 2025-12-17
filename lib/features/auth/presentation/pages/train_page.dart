import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import necessário
import 'package:firebase_core/firebase_core.dart'; // Import para usar o Firebase.app()

class TreinoDetalhesPage extends StatefulWidget {
  final String nomeTreino;
  final String grupoMuscular;
  final String treinoId; // Novo campo para receber o ID

  const TreinoDetalhesPage({
    super.key,
    required this.nomeTreino,
    required this.grupoMuscular,
    required this.treinoId, // Obrigatório
  });

  @override
  State<TreinoDetalhesPage> createState() => _TreinoDetalhesPageState();
}

class _TreinoDetalhesPageState extends State<TreinoDetalhesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeTreino),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Cabeçalho (Continua igual)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Foco de hoje:",
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
                ),
                Text(
                  widget.grupoMuscular,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
          ),

          // LISTA DE EXERCÍCIOS VINDO DO FIREBASE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Atenção: Conectando no banco 'okan', entrando no treino específico e pegando os exercícios
              stream: FirebaseFirestore.instance
                  .collection('treinos')
                  .doc(widget.treinoId) // Usa o ID que veio da Home
                  .collection('exercicios')
                  .orderBy('ordem') // Ordena (se você criou o campo ordem)
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. Carregando
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Vazio
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Nenhum exercício cadastrado."));
                }

                // 3. Sucesso
                final exercicios = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: exercicios.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dados = exercicios[index].data() as Map<String, dynamic>;
                    
                    final name = dados['name'] ?? 'Exercício';
                    final series = dados['series'] ?? '-';
                    
                    // Lógica simples de Checkbox local (não salva no banco ainda)
                    // Para salvar o check, precisaríamos atualizar o documento no Firebase
                    bool feito = false; 

                    return StatefulBuilder(
                      builder: (context, setStateItem) {
                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: feito ? TextDecoration.lineThrough : null,
                              color: feito ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            series,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          value: feito,
                          activeColor: Colors.blue,
                          onChanged: (bool? valor) {
                            setStateItem(() {
                              feito = valor ?? false;
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundColor: feito ? Colors.green.shade100 : Colors.blue.shade50,
                            child: Icon(
                              Icons.fitness_center,
                              color: feito ? Colors.green : Colors.blue,
                              size: 20,
                            ),
                          ),
                        );
                      }
                    );
                  },
                );
              },
            ),
          ),

          // Botão Finalizar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Treino concluído!')),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("FINALIZAR TREINO"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
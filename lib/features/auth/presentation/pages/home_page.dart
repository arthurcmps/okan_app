import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dados simulados (Mock) para visualizarmos o layout
    final List<Map<String, String>> treinos = [
      {
        "nome": "Treino A",
        "grupo": "Peito, Tríceps e Ombros",
        "duracao": "60 min",
        "exercicios": "8"
      },
      {
        "nome": "Treino B",
        "grupo": "Costas, Bíceps e Trapézio",
        "duracao": "55 min",
        "exercicios": "7"
      },
      {
        "nome": "Treino C",
        "grupo": "Pernas e Abdômen",
        "duracao": "70 min",
        "exercicios": "9"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá, Arthur', // Depois pegaremos do Firebase
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Vamos treinar hoje?',
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey[700], 
                fontWeight: FontWeight.normal
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
                // Voltaria para o login
                Navigator.pop(context); 
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seus Treinos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: treinos.length,
                itemBuilder: (context, index) {
                  final treino = treinos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Ação ao clicar no treino (Iremos para os detalhes depois)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Abrindo ${treino["nome"]}')),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  treino["nome"]!.split(" ")[1], // Pega a letra A, B ou C
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    treino["nome"]!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    treino["grupo"]!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        treino["duracao"]!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.fitness_center, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${treino['exercicios']} exercícios",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DashboardChart extends StatelessWidget {
  const DashboardChart({super.key});

  // Função auxiliar para verificar se duas datas são o mesmo dia
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Pega o início da semana (Domingo)
  DateTime _getStartOfWeek() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final startOfWeek = _getStartOfWeek();
    // Cria lista com os 7 dias da semana atual
    final weekDays = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('historico')
          .where('usuarioId', isEqualTo: user.uid)
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .snapshots(),
      builder: (context, snapshot) {
        // Lista de dias que o usuário treinou
        final treinosRealizados = <DateTime>[];

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = (doc['data'] as Timestamp).toDate();
            treinosRealizados.add(data);
          }
        }

        // Calcula frequência (quantos dias únicos treinou na semana)
        final diasUnicosTreinados = weekDays.where((day) {
          return treinosRealizados.any((treino) => _isSameDay(treino, day));
        }).length;

        return Card(
          // O Card Theme já foi definido no main.dart, não precisa repetir cor/sombra
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Atividade Semanal", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        SizedBox(height: 4),
                        Text("Frequência", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // Azul bem clarinho
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "$diasUnicosTreinados/7 dias",
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                
                // O GRÁFICO DE BARRAS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end, // Alinha as barras por baixo
                  children: weekDays.map((day) {
                    final bool treinouHoje = treinosRealizados.any((t) => _isSameDay(t, day));
                    final bool isToday = _isSameDay(day, DateTime.now());
                    
                    // Letra do dia (D, S, T, Q...)
                    String diaSemana = DateFormat('E', 'pt_BR').format(day)[0].toUpperCase();

                    return Column(
                      children: [
                        // A Barra
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          width: 12,
                          height: treinouHoje ? 60 : 20, // Altura muda se treinou
                          decoration: BoxDecoration(
                            // Se treinou: Degradê Azul. Se não: Cinza.
                            gradient: treinouHoje 
                                ? const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : null,
                            color: treinouHoje ? null : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // A Letra do dia
                        Text(
                          diaSemana,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? const Color(0xFF2563EB) : Colors.grey,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
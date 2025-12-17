import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardChart extends StatefulWidget {
  const DashboardChart({super.key});

  @override
  State<DashboardChart> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChart> {
  // Mapa para guardar a contagem: 'Seg': 1, 'Ter': 0, etc.
  Map<int, int> _treinosPorDia = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosSemana();
  }

  Future<void> _carregarDadosSemana() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final hoje = DateTime.now();
    final dataInicio = hoje.subtract(const Duration(days: 6));
    final inicioDoDia = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('historico')
          .where('usuarioId', isEqualTo: user.uid)
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
          .get();

      Map<int, int> contagem = {};
      for (int i = 0; i < 7; i++) contagem[i] = 0;

      for (var doc in snapshot.docs) {
        final dataTreino = (doc['data'] as Timestamp).toDate();
        final diferenca = hoje.difference(dataTreino).inDays;
        
        if (diferenca >= 0 && diferenca < 7) {
          int indexGrafico = 6 - diferenca;
          contagem[indexGrafico] = (contagem[indexGrafico] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _treinosPorDia = contagem;
        });
      }
    } catch (e) {
      debugPrint("Erro no gráfico: $e");
    } finally {
      // O SEGREDO: O 'finally' roda sempre, dando erro ou não.
      // Isso garante que o spinner vai parar de rodar.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Retorna a inicial do dia da semana (S, T, Q...)
  String _getDiaSemana(int indexReverso) {
    final hoje = DateTime.now();
    final data = hoje.subtract(Duration(days: 6 - indexReverso));
    return DateFormat('E', 'pt_BR').format(data)[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Calcula o máximo de treinos num dia para ajustar a altura do gráfico
    int maxTreinos = 1;
    _treinosPorDia.forEach((_, qtd) {
      if (qtd > maxTreinos) maxTreinos = qtd;
    });

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Frequência Semanal',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BarChart(
                  BarChartData(
                    maxY: maxTreinos.toDouble() + 1,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.round()} treinos',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _getDiaSemana(value.toInt()),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: _treinosPorDia.entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.toDouble(),
                            color: entry.value > 0 ? Colors.blue : Colors.grey.shade200,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxTreinos.toDouble() + 1,
                              color: Colors.transparent,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
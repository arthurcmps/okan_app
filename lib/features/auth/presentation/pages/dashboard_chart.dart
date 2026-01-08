import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DashboardChart extends StatefulWidget {
  const DashboardChart({super.key});

  @override
  State<DashboardChart> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChart> {
  // Cores do gráfico
  final Color barBackgroundColor = Colors.grey.shade200;
  final Color barColor = Colors.blueAccent;
  final Color touchedBarColor = Colors.deepPurple;

  int touchedIndex = -1;

  // Mapa para guardar contagem: { 0: 1, 1: 0, ... }
  Map<int, int> _treinosPorDia = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosSemanais();
  }

  Future<void> _carregarDadosSemanais() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    // Pega o início do dia de 6 dias atrás para ter uma semana completa
    final inicioSemana = DateTime(agora.year, agora.month, agora.day).subtract(const Duration(days: 6));

    try {
      final query = await FirebaseFirestore.instance
          .collection('historico')
          .where('usuarioId', isEqualTo: user.uid)
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioSemana))
          .get();

      // Inicializa o mapa com 0 para os últimos 7 dias (0 a 6)
      Map<int, int> contagem = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0};

      for (var doc in query.docs) {
        final dataTreino = (doc['data'] as Timestamp).toDate();
        
        // Calcula a diferença em dias. Se hoje (0), diferença é 0.
        // Vamos inverter para o gráfico onde 6 é hoje.
        final diferencaDias = agora.difference(dataTreino).inDays;
        
        if (diferencaDias >= 0 && diferencaDias <= 6) {
          final indexBarra = 6 - diferencaDias; 
          contagem[indexBarra] = (contagem[indexBarra] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _treinosPorDia = contagem;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar gráfico: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200, 
        child: Center(child: CircularProgressIndicator())
      );
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sua Atividade Semanal',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Treinos realizados nos últimos 7 dias',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BarChart(
                  mainBarData(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartData mainBarData() {
    return BarChartData(
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          // CORREÇÃO AQUI: Voltamos para o parâmetro compatível com sua versão
          tooltipBgColor: Colors.blueGrey, 
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              '${rod.toY.toInt()} Treinos',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
        touchCallback: (FlTouchEvent event, barTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                barTouchResponse == null ||
                barTouchResponse.spot == null) {
              touchedIndex = -1;
              return;
            }
            touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: getTitles,
            reservedSize: 30,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: showingGroups(),
      gridData: const FlGridData(show: false),
    );
  }

  Widget getTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    
    // Calcula o dia da semana
    final hoje = DateTime.now();
    final diaDaBarra = hoje.subtract(Duration(days: 6 - value.toInt()));
    final nomeDia = DateFormat('E', 'pt_BR').format(diaDaBarra);
    
    final text = nomeDia.substring(0, 1).toUpperCase();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(text, style: style),
    );
  }

  List<BarChartGroupData> showingGroups() {
    return List.generate(7, (i) {
      final double valor = (_treinosPorDia[i] ?? 0).toDouble();
      return makeGroupData(i, valor, isTouched: i == touchedIndex);
    });
  }

  BarChartGroupData makeGroupData(int x, double y, {bool isTouched = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isTouched ? touchedBarColor : barColor,
          width: 22,
          borderSide: isTouched
              ? const BorderSide(color: Colors.deepPurple, width: 2)
              : const BorderSide(color: Colors.white, width: 0),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 5, 
            color: barBackgroundColor,
          ),
        ),
      ],
      showingTooltipIndicators: isTouched ? [0] : [],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart'; // Ajuste o caminho se precisar

class EvolutionChartsPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const EvolutionChartsPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<EvolutionChartsPage> createState() => _EvolutionChartsPageState();
}

class _EvolutionChartsPageState extends State<EvolutionChartsPage> {
  // Controle de abas: 0 para Treinos, 1 para Avaliações
  int _selectedTab = 0;

  // Filtro de qual exercício mostrar no gráfico
  String _exercicioSelecionado = "Agachamento"; 
  
  // Filtro de qual medida corporal mostrar
  String _medidaSelecionada = "peso"; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Evolução Sankofa", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.studentName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- SELETOR DE ABAS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildTabButton(0, "Força (Treinos)", Icons.fitness_center)),
                const SizedBox(width: 12),
                Expanded(child: _buildTabButton(1, "Corpo (Medidas)", Icons.monitor_weight_outlined)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- CONTEÚDO DA ABA ---
          Expanded(
            child: _selectedTab == 0 ? _buildTreinosChart() : _buildAvaliacoesChart(),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUAIS ---

  Widget _buildTabButton(int index, String text, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.white54),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ABA 1: GRÁFICO DE TREINOS (EVOLUÇÃO DE CARGA) ---
  Widget _buildTreinosChart() {
    return Column(
      children: [
        // Dica: Futuramente, você pode buscar a lista de exercícios únicos do banco e preencher esse Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _exercicioSelecionado,
                dropdownColor: AppColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: ["Agachamento", "Supino", "Leg Press", "Levantamento Terra"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _exercicioSelecionado = val!),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workout_history')
                .where('studentId', isEqualTo: widget.studentId)
                .orderBy('dataRealizacao')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

              List<FlSpot> spots = [];
              List<String> datas = [];
              double maxCarga = 0;

              // Processa os dados do banco para o gráfico
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final exercicios = data['exercicios'] as List<dynamic>? ?? [];
                
                // Procura se o exercício selecionado foi feito neste dia
                for (var ex in exercicios) {
                  if (ex['nome'].toString().toLowerCase().contains(_exercicioSelecionado.toLowerCase())) {
                    double carga = double.tryParse(ex['carga'].toString()) ?? 0;
                    if (carga > 0) {
                      if (carga > maxCarga) maxCarga = carga;
                      
                      Timestamp? ts = data['dataRealizacao'];
                      if (ts != null) {
                        spots.add(FlSpot(spots.length.toDouble(), carga));
                        datas.add(DateFormat('dd/MM').format(ts.toDate()));
                      }
                    }
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(child: Text("Sem dados suficientes para este exercício.", style: TextStyle(color: Colors.white54)));
              }

              return Padding(
                padding: const EdgeInsets.only(right: 24, left: 16, bottom: 24),
                child: _buildLineChart(spots, datas, maxCarga, AppColors.primary, "kg"),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- ABA 2: GRÁFICO DE AVALIAÇÕES CORPORAIS ---
  Widget _buildAvaliacoesChart() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildMedidaChip("peso", "Peso (kg)"),
              const SizedBox(width: 8),
              _buildMedidaChip("gordura", "Gordura (%)"),
              const SizedBox(width: 8),
              _buildMedidaChip("massa_magra", "M. Magra (kg)"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // NOTA: Ajuste o caminho da coleção de avaliações conforme o seu banco de dados
            stream: FirebaseFirestore.instance
                .collection('assessments')
                .where('studentId', isEqualTo: widget.studentId)
                .orderBy('date')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

              List<FlSpot> spots = [];
              List<String> datas = [];
              double maxValue = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                
                // Tenta ler o valor dependendo do que foi selecionado
                double valor = 0;
                if (_medidaSelecionada == "peso" && data['peso'] != null) valor = double.tryParse(data['peso'].toString()) ?? 0;
                if (_medidaSelecionada == "gordura" && data['gordura'] != null) valor = double.tryParse(data['gordura'].toString()) ?? 0;
                if (_medidaSelecionada == "massa_magra" && data['massa_magra'] != null) valor = double.tryParse(data['massa_magra'].toString()) ?? 0;

                if (valor > 0) {
                  if (valor > maxValue) maxValue = valor;
                  Timestamp? ts = data['date'];
                  if (ts != null) {
                    spots.add(FlSpot(spots.length.toDouble(), valor));
                    datas.add(DateFormat('MMM/yy').format(ts.toDate()));
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(child: Text("Nenhuma avaliação cadastrada ainda.", style: TextStyle(color: Colors.white54)));
              }

              // Escolhe a cor dependendo da aba (Secundária para corpo)
              return Padding(
                padding: const EdgeInsets.only(right: 24, left: 16, bottom: 24),
                child: _buildLineChart(
                  spots, datas, maxValue, 
                  AppColors.secondary, 
                  _medidaSelecionada == "gordura" ? "%" : "kg"
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMedidaChip(String valor, String label) {
    final isSelected = _medidaSelecionada == valor;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _medidaSelecionada = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: isSelected ? AppColors.secondary : Colors.white24),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              color: isSelected ? AppColors.secondary : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            )
          ),
        ),
      ),
    );
  }

  // --- O CORAÇÃO DO GRÁFICO (FL_CHART NEON) ---
  Widget _buildLineChart(List<FlSpot> spots, List<String> datas, double maxValue, Color lineColor, String sufixo) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxValue + (maxValue * 0.2), // Dá um respiro de 20% no topo do gráfico
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 100 ? 20 : 10,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < datas.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(datas[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('');
                return Text("${value.toInt()}$sufixo", style: const TextStyle(color: Colors.white54, fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false), // Sem borda quadrada feia
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true, // Linha suave e futurista
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.background,
                strokeWidth: 2,
                strokeColor: lineColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              // Efeito de sombra Neon debaixo da linha
              gradient: LinearGradient(
                colors: [lineColor.withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
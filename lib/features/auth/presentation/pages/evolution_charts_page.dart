import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

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

class _EvolutionChartsPageState extends State<EvolutionChartsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Variáveis para a Aba de Medidas
  String _medidaSelecionada = "weight"; // Padrão: Peso
  final Map<String, String> _opcoesMedidas = {
    "weight": "Peso Corporal (kg)",
    "bodyFatPercentage": "% Gordura",
    "muscleMassKg": "Massa Muscular (kg)",
    "abdomen": "Abdômen (cm)",
  };

  // Variáveis para a Aba de Treinos (Força)
  String? _exercicioSelecionado;
  List<String> _exerciciosDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarExerciciosDoHistorico();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Busca todos os treinos do aluno para ver quais exercícios ele já fez e gerar o menu Dropdown
  Future<void> _carregarExerciciosDoHistorico() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('workout_history')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      Set<String> exerciciosUnicos = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final listaEx = data['exercicios'] as List<dynamic>? ?? [];
        for (var ex in listaEx) {
          if (ex['nome'] != null && (ex['carga'] != null && ex['carga'].toString().isNotEmpty)) {
            exerciciosUnicos.add(ex['nome'].toString());
          }
        }
      }

      if (mounted) {
        setState(() {
          _exerciciosDisponiveis = exerciciosUnicos.toList()..sort();
          if (_exerciciosDisponiveis.isNotEmpty) {
            _exercicioSelecionado = _exerciciosDisponiveis.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar exercícios do histórico: $e");
    }
  }

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
            Text(widget.studentName, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white38,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Medidas Corporais", icon: Icon(Icons.monitor_weight_outlined)),
            Tab(text: "Força / Cargas", icon: Icon(Icons.fitness_center)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaMedidas(),
          _buildAbaForca(),
        ],
      ),
    );
  }

  // ==============================================================
  // ABA 1: MEDIDAS CORPORAIS
  // ==============================================================
  Widget _buildAbaMedidas() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            value: _medidaSelecionada,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Métrica Analisada",
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _opcoesMedidas.entries.map((e) {
              return DropdownMenuItem(value: e.key, child: Text(e.value));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _medidaSelecionada = val);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.studentId)
                .collection('assessments')
                .orderBy('date')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text("Nenhuma avaliação encontrada.", style: TextStyle(color: Colors.white54)));

              // Prepara os dados para o gráfico
              List<FlSpot> spots = [];
              List<String> datasFormatadas = [];
              double minY = double.infinity;
              double maxY = double.negativeInfinity;

              for (int i = 0; i < docs.length; i++) {
                final data = docs[i].data() as Map<String, dynamic>;
                
                // Converte a data
                DateTime dataRef = DateTime.now();
                if (data['date'] is Timestamp) {
                  dataRef = (data['date'] as Timestamp).toDate();
                } else if (data['date'] is String) {
                  dataRef = DateTime.tryParse(data['date']) ?? DateTime.now();
                }
                datasFormatadas.add(DateFormat('dd/MM', 'pt_BR').format(dataRef));

                // Puxa o valor da métrica escolhida
                final valorBruto = data[_medidaSelecionada];
                if (valorBruto != null) {
                  double valor = double.tryParse(valorBruto.toString()) ?? 0.0;
                  if (valor > 0) {
                    spots.add(FlSpot(i.toDouble(), valor));
                    if (valor < minY) minY = valor;
                    if (valor > maxY) maxY = valor;
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(child: Text("Métrica sem dados registrados.", style: TextStyle(color: Colors.white54)));
              }

              return Padding(
                padding: const EdgeInsets.only(right: 24, left: 10, top: 24, bottom: 24),
                child: _buildGraficoSankofa(spots, datasFormatadas, minY, maxY, AppColors.primary),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // ABA 2: FORÇA E PROGRESSÃO DE CARGAS
  // ==============================================================
  Widget _buildAbaForca() {
    if (_exerciciosDisponiveis.isEmpty) {
      return const Center(child: Text("O aluno ainda não registou cargas nos treinos.", style: TextStyle(color: Colors.white54)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            value: _exercicioSelecionado,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Exercício Analisado",
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _exerciciosDisponiveis.map((ex) {
              return DropdownMenuItem(value: ex, child: Text(ex));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _exercicioSelecionado = val);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workout_history')
                .where('studentId', isEqualTo: widget.studentId)
                .orderBy('dataRealizacao')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
              
              final docs = snapshot.data?.docs ?? [];
              
              List<FlSpot> spots = [];
              List<String> datasFormatadas = [];
              double minY = double.infinity;
              double maxY = double.negativeInfinity;
              int indexX = 0;

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final listaEx = data['exercicios'] as List<dynamic>? ?? [];
                
                // Procura se o aluno fez este exercício neste dia
                for (var ex in listaEx) {
                  if (ex['nome'] == _exercicioSelecionado && ex['carga'] != null) {
                    double carga = double.tryParse(ex['carga'].toString().replaceAll(',', '.')) ?? 0.0;
                    
                    if (carga > 0) {
                      DateTime dataRef = (data['dataRealizacao'] as Timestamp).toDate();
                      datasFormatadas.add(DateFormat('dd/MM').format(dataRef));
                      
                      spots.add(FlSpot(indexX.toDouble(), carga));
                      if (carga < minY) minY = carga;
                      if (carga > maxY) maxY = carga;
                      
                      indexX++;
                      break; // Se encontrou o exercício neste dia, avança para o próximo dia
                    }
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(child: Text("Sem evolução de carga para este exercício.", style: TextStyle(color: Colors.white54)));
              }

              return Padding(
                padding: const EdgeInsets.only(right: 24, left: 10, top: 24, bottom: 24),
                // Gráfico de força usa a cor Secundária (Terracota)
                child: _buildGraficoSankofa(spots, datasFormatadas, minY, maxY, AppColors.secondary),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // O MOTOR VISUAL: GRÁFICO FL_CHART (Design Futurista/Sankofa)
  // ==============================================================
  Widget _buildGraficoSankofa(List<FlSpot> spots, List<String> datasFormatadas, double minY, double maxY, Color corTema) {
    
    // Dá uma margem de respiração ao gráfico para a linha não colar no teto ou chão
    double margem = (maxY - minY) * 0.2;
    if (margem == 0) margem = 5; 

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: (minY - margem).clamp(0, double.infinity), // Nunca fica abaixo de 0
        maxY: maxY + margem,
        
        // --- EIXOS E TEXTOS ---
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // Mostra o rótulo a cada 1 ponto
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < datasFormatadas.length) {
                  // Só mostra algumas datas se houverem muitos pontos (evita sobreposição)
                  if (spots.length > 7 && index % 2 != 0) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(datasFormatadas[index], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                // Formata os números do lado esquerdo
                return Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Esconde o eixo de cima
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Esconde o eixo da direita
        ),
        
        // --- GRELHA DE FUNDO ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // Sem linhas verticais para ficar mais "limpo"
          horizontalInterval: margem > 0 ? margem : 1,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.white10, strokeWidth: 1, dashArray: [5, 5]); // Linhas pontilhadas
          },
        ),
        
        // --- TOOLTIP (O BALÃO QUANDO SE CLICA NA LINHA) ---
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => AppColors.surface, // Fundo escuro do balão
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  "${spot.y.toStringAsFixed(1)}\n${datasFormatadas[spot.x.toInt()]}",
                  TextStyle(color: corTema, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        
        borderData: FlBorderData(show: false), // Sem borda quadrada exterior
        
        // --- A LINHA E A SOMBRA DO GRÁFICO ---
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true, // Curvas suaves
            color: corTema,
            barWidth: 4,
            isStrokeCapRound: true,
            
            // Pontos luminosos onde há dados
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.background,
                strokeWidth: 2,
                strokeColor: corTema,
              ),
            ),
            
            // O gradiente/sombra debaixo da linha
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [corTema.withOpacity(0.4), corTema.withOpacity(0.0)],
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
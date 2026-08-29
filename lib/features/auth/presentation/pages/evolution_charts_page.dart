import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workouts/data/repositories/firebase_workouts_repository.dart';
import '../../../workouts/domain/entities/workout_history.dart';
import '../../../workouts/domain/repositories/workouts_repository.dart';

class EvolutionChartsPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final WorkoutsRepository? workoutsRepository;

  const EvolutionChartsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    this.workoutsRepository,
  });

  @override
  State<EvolutionChartsPage> createState() => _EvolutionChartsPageState();
}

class _EvolutionChartsPageState extends State<EvolutionChartsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final WorkoutsRepository _workoutsRepository;

  String _medidaSelecionada = 'weight';
  final Map<String, String> _opcoesMedidas = {
    'weight': 'Peso Corporal (kg)',
    'bodyFatPercentage': '% Gordura',
    'muscleMassKg': 'Massa Muscular (kg)',
    'abdomen': 'Abdômen (cm)',
  };

  String? _exercicioSelecionado;
  List<String> _exerciciosDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _workoutsRepository =
        widget.workoutsRepository ?? FirebaseWorkoutsRepository();
    _tabController = TabController(length: 2, vsync: this);
    _carregarExerciciosDoHistorico();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarExerciciosDoHistorico() async {
    try {
      final history = await _workoutsRepository
          .watchWorkoutHistory(widget.studentId)
          .first;

      final exerciciosUnicos = <String>{};
      for (final record in history) {
        for (final exercise in record.exercicios) {
          if (exercise.nome.trim().isNotEmpty && exercise.carga.trim().isNotEmpty) {
            exerciciosUnicos.add(exercise.nome.trim());
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _exerciciosDisponiveis = exerciciosUnicos.toList()..sort();
        if (_exerciciosDisponiveis.isNotEmpty) {
          _exercicioSelecionado = _exerciciosDisponiveis.first;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar exercícios do histórico: $e');
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
            const Text(
              'Evolução Sankofa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.studentName,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white38,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              text: 'Medidas Corporais',
              icon: Icon(Icons.monitor_weight_outlined),
            ),
            Tab(text: 'Força / Cargas', icon: Icon(Icons.fitness_center)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAbaMedidas(), _buildAbaForca()],
      ),
    );
  }

  Widget _buildAbaMedidas() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _medidaSelecionada,
            dropdownColor: AppColors.surface,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Métrica Analisada',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _opcoesMedidas.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _medidaSelecionada = value);
              }
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma avaliação encontrada.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              final spots = <FlSpot>[];
              final datasFormatadas = <String>[];
              double minY = double.infinity;
              double maxY = double.negativeInfinity;

              for (var i = 0; i < docs.length; i++) {
                final data = docs[i].data() as Map<String, dynamic>;

                var dataRef = DateTime.now();
                if (data['date'] is Timestamp) {
                  dataRef = (data['date'] as Timestamp).toDate();
                } else if (data['date'] is String) {
                  dataRef = DateTime.tryParse(data['date']) ?? DateTime.now();
                }
                datasFormatadas.add(
                  DateFormat('dd/MM', 'pt_BR').format(dataRef),
                );

                final valorBruto = data[_medidaSelecionada];
                if (valorBruto != null) {
                  final valor = double.tryParse(valorBruto.toString()) ?? 0;
                  if (valor > 0) {
                    spots.add(FlSpot(i.toDouble(), valor));
                    if (valor < minY) minY = valor;
                    if (valor > maxY) maxY = valor;
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(
                  child: Text(
                    'Métrica sem dados registrados.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(
                  right: 24,
                  left: 10,
                  top: 24,
                  bottom: 24,
                ),
                child: _buildGraficoSankofa(
                  spots,
                  datasFormatadas,
                  minY,
                  maxY,
                  AppColors.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbaForca() {
    if (_exerciciosDisponiveis.isEmpty) {
      return const Center(
        child: Text(
          'O aluno ainda não registou cargas nos treinos.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _exercicioSelecionado,
            dropdownColor: AppColors.surface,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Exercício Analisado',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _exerciciosDisponiveis
                .map(
                  (exercise) => DropdownMenuItem(
                    value: exercise,
                    child: Text(exercise),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _exercicioSelecionado = value);
              }
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<WorkoutHistory>>(
            stream: _workoutsRepository.watchWorkoutHistory(widget.studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                );
              }

              final history = <WorkoutHistory>[
                ...?snapshot.data,
              ]..sort(
                  (a, b) => a.dataRealizacao.compareTo(b.dataRealizacao),
                );

              final spots = <FlSpot>[];
              final datasFormatadas = <String>[];
              double minY = double.infinity;
              double maxY = double.negativeInfinity;
              var indexX = 0;

              for (final record in history) {
                for (final exercise in record.exercicios) {
                  if (exercise.nome == _exercicioSelecionado &&
                      exercise.carga.trim().isNotEmpty) {
                    final cargaLimpa = exercise.carga
                        .replaceAll(',', '.')
                        .replaceAll(RegExp(r'[^0-9.]'), '');
                    final carga = double.tryParse(cargaLimpa) ?? 0;

                    if (carga > 0) {
                      datasFormatadas.add(
                        DateFormat('dd/MM').format(record.dataRealizacao),
                      );
                      spots.add(FlSpot(indexX.toDouble(), carga));
                      if (carga < minY) minY = carga;
                      if (carga > maxY) maxY = carga;
                      indexX++;
                      break;
                    }
                  }
                }
              }

              if (spots.isEmpty) {
                return const Center(
                  child: Text(
                    'Sem evolução de carga para este exercício.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(
                  right: 24,
                  left: 10,
                  top: 24,
                  bottom: 24,
                ),
                child: _buildGraficoSankofa(
                  spots,
                  datasFormatadas,
                  minY,
                  maxY,
                  AppColors.secondary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGraficoSankofa(
    List<FlSpot> spots,
    List<String> datasFormatadas,
    double minY,
    double maxY,
    Color corTema,
  ) {
    var margem = (maxY - minY) * 0.2;
    if (margem == 0) margem = 5;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
        minY: (minY - margem).clamp(0, double.infinity),
        maxY: maxY + margem,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < datasFormatadas.length) {
                  if (spots.length > 7 && index % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      datasFormatadas[index],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
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
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: margem > 0 ? margem : 1,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => AppColors.surface,
            getTooltipItems: (touchedSpots) => touchedSpots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)}\n${datasFormatadas[spot.x.toInt()]}',
                    TextStyle(
                      color: corTema,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: corTema,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.background,
                    strokeWidth: 2,
                    strokeColor: corTema,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  corTema.withOpacity(0.4),
                  corTema.withOpacity(0),
                ],
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

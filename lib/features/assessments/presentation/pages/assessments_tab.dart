import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/okan_async_state.dart';
import '../../data/repositories/firebase_assessments_repository.dart';
import '../../domain/entities/physical_assessment.dart';
import '../../domain/repositories/assessments_repository.dart';
import '../widgets/professor_notes_widget.dart';

class AssessmentsTab extends StatefulWidget {
  const AssessmentsTab({
    super.key,
    required this.studentId,
    this.repository,
  });

  final String studentId;
  final AssessmentsRepository? repository;

  @override
  State<AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends State<AssessmentsTab> {
  late final AssessmentsRepository _repository;
  late Stream<List<PhysicalAssessment>> _assessmentsStream;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseAssessmentsRepository();
    _assessmentsStream = _repository.watchAssessments(widget.studentId);
  }

  void _retryLoading() {
    setState(() {
      _assessmentsStream = _repository.watchAssessments(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_chart, color: Colors.black),
        label: const Text(
          'Nova Avaliação',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddAssessmentModal(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ProfessorNotesWidget(
              studentId: widget.studentId,
              repository: _repository,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PhysicalAssessment>>(
              stream: _assessmentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const OkanLoadingState(
                    label: 'Carregando avaliações físicas',
                  );
                }

                if (snapshot.hasError) {
                  return OkanMessageState(
                    key: const ValueKey('assessments-error'),
                    icon: Icons.cloud_off_outlined,
                    title: 'Não foi possível carregar as avaliações',
                    description:
                        'Verifique sua conexão e tente novamente em alguns instantes.',
                    actionLabel: 'Tentar novamente',
                    onAction: _retryLoading,
                    isError: true,
                    announce: true,
                  );
                }

                final assessments =
                    snapshot.data ?? const <PhysicalAssessment>[];
                if (assessments.isEmpty) {
                  return const OkanMessageState(
                    key: ValueKey('assessments-empty'),
                    icon: Icons.add_chart_outlined,
                    title: 'Nenhuma avaliação registrada',
                    description:
                        'Use “Nova Avaliação” para registrar os primeiros dados.',
                  );
                }

                return ListView.builder(
                  itemCount: assessments.length,
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 90,
                  ),
                  itemBuilder: (context, index) {
                    final assessment = assessments[index];
                    final data = assessment.values;

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        iconColor: AppColors.secondary,
                        collapsedIconColor: Colors.white70,
                        title: Text(
                          DateFormat('dd/MM/yyyy').format(assessment.date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "${data['weight']}kg  |  BF: ${data['bodyFatPercentage'] ?? '-'}%  |  ${data['generalRating'] ?? ''}",
                          style: const TextStyle(color: AppColors.secondary),
                        ),
                        children: [
                          _buildSectionHeader('Medidas Corporais'),
                          _buildDetailRow('Peso', "${data['weight']} kg"),
                          _buildDetailRow('Altura', "${data['height']} cm"),
                          _buildDetailRow('Pescoço', "${data['neck'] ?? '-'} cm"),
                          _buildDetailRow('Ombros', "${data['shoulders'] ?? '-'} cm"),
                          _buildDetailRow('Tórax', "${data['chest'] ?? '-'} cm"),
                          _buildDetailRow('Cintura', "${data['waist'] ?? '-'} cm"),
                          _buildDetailRow('Abdômen', "${data['abdomen'] ?? '-'} cm"),
                          _buildDetailRow('Quadril', "${data['hips'] ?? '-'} cm"),
                          const Divider(color: Colors.white10),
                          _buildSectionHeader('Membros (Dir / Esq)'),
                          _buildDetailRow(
                            'Braço Relaxado',
                            "${data['armRightRelaxed'] ?? '-'} / ${data['armLeftRelaxed'] ?? '-'} cm",
                          ),
                          _buildDetailRow(
                            'Braço Contraído',
                            "${data['armRightContracted'] ?? '-'} / ${data['armLeftContracted'] ?? '-'} cm",
                          ),
                          _buildDetailRow(
                            'Antebraço',
                            "${data['forearmRight'] ?? '-'} / ${data['forearmLeft'] ?? '-'} cm",
                          ),
                          _buildDetailRow(
                            'Coxa Medial',
                            "${data['thighRight'] ?? '-'} / ${data['thighLeft'] ?? '-'} cm",
                          ),
                          _buildDetailRow(
                            'Panturrilha',
                            "${data['calfRight'] ?? '-'} / ${data['calfLeft'] ?? '-'} cm",
                          ),
                          const Divider(color: Colors.white10),
                          _buildSectionHeader('Bioimpedância'),
                          _buildDetailRow('IMC', _formatImc(data['imc'])),
                          _buildDetailRow(
                            '% Gordura',
                            "${data['bodyFatPercentage'] ?? '-'} %",
                          ),
                          _buildDetailRow(
                            'Massa Gorda',
                            "${data['fatMassKg'] ?? '-'} kg",
                          ),
                          _buildDetailRow(
                            'Massa Muscular',
                            "${data['muscleMassKg'] ?? '-'} kg",
                          ),
                          _buildDetailRow(
                            'Gordura Visceral',
                            "${data['visceralFat'] ?? '-'} (1-9)",
                          ),
                          _buildDetailRow(
                            'Metabolismo Basal',
                            "${data['basalMetabolism'] ?? '-'} Kcal",
                          ),
                          _buildDetailRow(
                            'Idade Metabólica',
                            "${data['metabolicAge'] ?? '-'} anos",
                          ),
                          _buildDetailRow(
                            'Água Corporal',
                            "${data['bodyWaterPercentage'] ?? '-'} %",
                          ),
                          _buildDetailRow(
                            'Massa Óssea',
                            "${data['boneMass'] ?? '-'} kg",
                          ),
                          _buildDetailRow(
                            'Avaliação Geral',
                            "${data['generalRating'] ?? '-'}",
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
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

  String _formatImc(dynamic value) {
    if (value is num) return value.toDouble().toStringAsFixed(2);
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed?.toStringAsFixed(2) ?? '-';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAssessmentModal(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _AssessmentForm(
          studentId: widget.studentId,
          scrollController: controller,
          repository: _repository,
        ),
      ),
    );
  }
}

class _AssessmentForm extends StatefulWidget {
  const _AssessmentForm({
    required this.studentId,
    required this.scrollController,
    required this.repository,
  });

  final String studentId;
  final ScrollController scrollController;
  final AssessmentsRepository repository;

  @override
  State<_AssessmentForm> createState() => _AssessmentFormState();
}

class _AssessmentFormState extends State<_AssessmentForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  bool _isSaving = false;

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'generalRating': _values['generalRating'],
    };

    for (final entry in _values.entries) {
      if (entry.value.isNotEmpty && entry.key != 'generalRating') {
        data[entry.key] =
            double.tryParse(entry.value.replaceAll(',', '.')) ?? entry.value;
      }
    }

    data['imc'] = calculateBodyMassIndex(
      weight: _toDouble(data['weight']),
      height: _toDouble(data['height']),
    );

    try {
      await widget.repository.addAssessment(
        studentId: widget.studentId,
        values: data,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Avaliação salva!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      debugPrint('AssessmentForm/addAssessment: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a avaliação. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Text(
            'Nova Avaliação Física',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Dados Principais'),
          _inputRow('Peso (kg)', 'weight', 'Altura (cm)', 'height', required: true),
          _sectionTitle('Perimetria (Tronco)'),
          _inputRow('Pescoço', 'neck', 'Ombros', 'shoulders'),
          _inputRow('Tórax', 'chest', 'Cintura', 'waist'),
          _inputRow('Abdômen', 'abdomen', 'Quadril', 'hips'),
          _sectionTitle('Membros Superiores (Dir / Esq)'),
          _pairLabel('Braço Relaxado'),
          _inputRow('Direito', 'armRightRelaxed', 'Esquerdo', 'armLeftRelaxed'),
          _pairLabel('Braço Contraído'),
          _inputRow('Direito', 'armRightContracted', 'Esquerdo', 'armLeftContracted'),
          _pairLabel('Antebraço'),
          _inputRow('Direito', 'forearmRight', 'Esquerdo', 'forearmLeft'),
          _sectionTitle('Membros Inferiores (Dir / Esq)'),
          _pairLabel('Coxa Medial'),
          _inputRow('Direita', 'thighRight', 'Esquerda', 'thighLeft'),
          _pairLabel('Panturrilha'),
          _inputRow('Direita', 'calfRight', 'Esquerda', 'calfLeft'),
          const Divider(color: Colors.white24, height: 40),
          _sectionTitle('Bioimpedância'),
          _inputRow('% Gordura (BF)', 'bodyFatPercentage', 'Massa Gorda (kg)', 'fatMassKg'),
          _inputRow('Massa Musc. (kg)', 'muscleMassKg', 'Gord. Visceral (1-9)', 'visceralFat'),
          _inputRow('Metabolismo (Kcal)', 'basalMetabolism', 'Idade Metab.', 'metabolicAge'),
          _inputRow('Água Corporal %', 'bodyWaterPercentage', 'Massa Óssea (kg)', 'boneMass'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _values['generalRating']?.isNotEmpty == true
                ? _values['generalRating']
                : null,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Avaliação Geral',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
            items: ['Ruim', 'Bom', 'Ótimo']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(
                      () => _values['generalRating'] = value ?? '',
                    );
                  },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            key: const ValueKey('assessment-save'),
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'SALVAR AVALIAÇÃO COMPLETA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _inputRow(
    String leftLabel,
    String leftKey,
    String rightLabel,
    String rightKey, {
    bool required = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBodySize = MediaQuery.textScalerOf(context).scale(16);
        final useVerticalLayout =
            constraints.maxWidth < 480 || scaledBodySize >= 24;

        if (useVerticalLayout) {
          return Column(
            children: [
              _input(leftLabel, leftKey, required: required),
              _input(rightLabel, rightKey, required: required),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _input(leftLabel, leftKey, required: required)),
            const SizedBox(width: 10),
            Expanded(child: _input(rightLabel, rightKey, required: required)),
          ],
        );
      },
    );
  }

  Widget _pairLabel(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _input(String label, String key, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: _values[key],
        enabled: !_isSaving,
        onChanged: (value) => _values[key] = value,
        style: const TextStyle(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white12),
          ),
          isDense: true,
        ),
        validator: required
            ? (value) => value == null || value.isEmpty ? 'Obrigatório' : null
            : null,
        onSaved: (value) => _values[key] = value ?? '',
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/firebase_assessments_repository.dart';
import '../../domain/repositories/assessments_repository.dart';
import '../widgets/professor_notes_widget.dart';

class AnamneseTab extends StatefulWidget {
  const AnamneseTab({
    super.key,
    required this.studentId,
    this.isEditable = true,
    this.repository,
  });

  final String studentId;
  final bool isEditable;
  final AssessmentsRepository? repository;

  @override
  State<AnamneseTab> createState() => _AnamneseTabState();
}

class _AnamneseTabState extends State<AnamneseTab> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _formData = {};
  late final AssessmentsRepository _repository;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseAssessmentsRepository();
    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final record = await _repository.loadAnamnese(widget.studentId);
      if (!mounted) return;

      setState(() {
        _formData
          ..clear()
          ..addAll(record.values);

        for (final entry in _formData.entries) {
          if (entry.value is String) {
            (_controllers[entry.key] ??= TextEditingController()).text =
                entry.value as String;
          }
        }
      });
    } catch (error) {
      debugPrint('Erro ao carregar anamnese: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAnamnese() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    for (final entry in _controllers.entries) {
      _formData[entry.key] = entry.value.text;
    }

    try {
      await _repository.saveAnamnese(
        studentId: widget.studentId,
        values: _formData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ficha salva com sucesso! ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      FocusScope.of(context).unfocus();
    } catch (error) {
      debugPrint('Erro ao salvar anamnese: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a ficha.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfessorNotesWidget(
            studentId: widget.studentId,
            repository: _repository,
          ),
          const SizedBox(height: 10),
          _buildSection('1. Objetivos', [
            _buildMultiSelect('Objetivos Principais', [
              'Hipertrofia',
              'Emagrecimento',
              'Condicionamento',
              'Reabilitação',
              'Saúde Geral',
            ]),
            _buildTextField('Esporte Específico (Se houver)', 'esporte_especifico'),
            _buildTextField('Prazo esperado para resultados', 'prazo_resultados'),
          ]),
          _buildSection('2. Histórico de Atividade', [
            _buildSingleSelect(
              'Nível Atual',
              ['Sedentário', 'Iniciante', 'Intermediário', 'Avançado'],
              'nivel_atividade',
            ),
            _buildTextField('Já praticou musculação? Tempo?', 'historico_musculacao'),
            _buildTextField('Outros esportes atuais', 'outros_esportes'),
          ]),
          _buildSection('3. Saúde e Triagem', [
            _buildYesNoWithText('Possui lesão?', 'lesao', 'Onde?'),
            _buildMultiSelect('Dores frequentes', [
              'Joelhos',
              'Ombros',
              'Lombar',
              'Cervical',
              'Punhos',
            ]),
            _buildYesNo('Problemas Cardíacos?', 'cardiaco'),
            _buildYesNo('Tonturas/Falta de ar?', 'tonturas'),
            _buildYesNoWithText('Cirurgia recente?', 'cirurgia', 'Qual?'),
            _buildYesNoWithText(
              'Medicamento contínuo?',
              'medicamento',
              'Qual?',
            ),
            _buildYesNo('Tem liberação médica?', 'liberacao_medica'),
          ]),
          _buildSection('4. Estilo de Vida', [
            _buildSingleSelect(
              'Qualidade do Sono',
              ['Boa (7-8h)', 'Regular', 'Ruim'],
              'sono',
            ),
            _buildSingleSelect(
              'Alimentação',
              ['Nutricionista', 'Saudável s/ acomp.', 'Irregular'],
              'alimentacao',
            ),
            _buildTextField('Nível de Estresse (1-10)', 'estresse'),
            _buildTextField('Fuma ou Bebe?', 'fumante_alcool'),
          ]),
          _buildSection('5. Logística e Preferências', [
            _buildSingleSelect(
              'Frequência Semanal',
              ['2x', '3x', '4x', '5x', '6x', 'Todos os dias'],
              'freq_semanal',
            ),
            _buildSingleSelect(
              'Tempo Disponível',
              ['30-40 min', '45-60 min', '+1h'],
              'tempo_treino',
            ),
            _buildTextField('Horário Preferido', 'horario_treino'),
            _buildTextField('O que MAIS gosta na academia?', 'gosta_fazer'),
            _buildTextField('O que DETESTA fazer?', 'detesta_fazer'),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveAnamnese,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'SALVAR FICHA',
              style: TextStyle(
                color: Colors.black,
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

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconColor: AppColors.secondary,
          collapsedIconColor: Colors.white54,
          children: children
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: child,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key) {
    final controller = _controllers[key] ??= TextEditingController();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: widget.isEditable,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.secondary),
          ),
        ),
      ),
    );
  }

  Widget _buildYesNo(String question, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            _radioOption('Sim', true, key),
            _radioOption('Não', false, key),
          ],
        ),
      ],
    );
  }

  Widget _buildYesNoWithText(String question, String key, String ifYesLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYesNo(question, key),
        if (_formData[key] == true)
          _buildTextField(ifYesLabel, '${key}_detalhe'),
      ],
    );
  }

  Widget _radioOption(String label, bool value, String key) {
    return Row(
      children: [
        Radio<bool>(
          value: value,
          groupValue: _formData[key],
          activeColor: AppColors.secondary,
          onChanged: widget.isEditable
              ? (selected) => setState(() => _formData[key] = selected)
              : null,
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildSingleSelect(
    String title,
    List<String> options,
    String key,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = _formData[key] == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: AppColors.secondary,
              backgroundColor: Colors.black26,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: widget.isEditable
                  ? (selected) => setState(
                      () => _formData[key] = selected ? option : null,
                    )
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMultiSelect(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final key = 'check_${option.toLowerCase()}';
            final isSelected = _formData[key] == true;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: AppColors.secondary.withOpacity(0.8),
              checkmarkColor: Colors.black,
              backgroundColor: Colors.black26,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
              ),
              onSelected: widget.isEditable
                  ? (selected) => setState(() => _formData[key] = selected)
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

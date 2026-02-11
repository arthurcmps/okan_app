import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';

class AnamneseTab extends StatefulWidget {
  final String studentId;
  final bool isEditable; // Se for o Personal, pode editar? Ou só o aluno?

  const AnamneseTab({super.key, required this.studentId, this.isEditable = true});

  @override
  State<AnamneseTab> createState() => _AnamneseTabState();
}

class _AnamneseTabState extends State<AnamneseTab> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers para campos de texto livre
  final Map<String, TextEditingController> _controllers = {};
  
  // Map para guardar os valores dos checkboxes e radios
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).collection('medical').doc('anamnese').get();
    if (doc.exists) {
      setState(() {
        _formData.addAll(doc.data()!);
        // Atualiza controllers se necessário
        _formData.forEach((key, value) {
          if (value is String) {
            _controllers.putIfAbsent(key, () => TextEditingController(text: value));
          }
        });
      });
    }
  }

  Future<void> _saveAnamnese() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Salva também o texto dos controllers no map
      _controllers.forEach((key, controller) {
        _formData[key] = controller.text;
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('medical')
          .doc('anamnese')
          .set(_formData, SetOptions(merge: true));

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anamnese salva!"), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection("1. Objetivos", [
            _buildMultiSelect("Objetivos Principais", [
              "Hipertrofia", "Emagrecimento", "Condicionamento", "Reabilitação", "Saúde Geral"
            ]),
            _buildTextField("Esporte Específico (Se houver)", "esporte_especifico"),
            _buildTextField("Prazo esperado para resultados", "prazo_resultados"),
          ]),

          _buildSection("2. Histórico de Atividade", [
            _buildSingleSelect("Nível Atual", ["Sedentário", "Iniciante", "Intermediário", "Avançado"], "nivel_atividade"),
            _buildTextField("Já praticou musculação? Tempo?", "historico_musculacao"),
            _buildTextField("Outros esportes atuais", "outros_esportes"),
          ]),

          _buildSection("3. Saúde e Triagem (Importante!)", [
            _buildYesNoWithText("Possui lesão?", "lesao", "Onde?"),
            _buildMultiSelect("Dores frequentes", ["Joelhos", "Ombros", "Lombar", "Cervical", "Punhos"]),
            _buildYesNo("Problemas Cardíacos?", "cardiaco"),
            _buildYesNo("Tonturas/Falta de ar?", "tonturas"),
            _buildYesNoWithText("Cirurgia recente?", "cirurgia", "Qual?"),
            _buildYesNoWithText("Medicamento contínuo?", "medicamento", "Qual?"),
            _buildYesNo("Tem liberação médica?", "liberacao_medica"),
          ]),

          _buildSection("4. Estilo de Vida", [
             _buildSingleSelect("Qualidade do Sono", ["Boa (7-8h)", "Regular", "Ruim"], "sono"),
             _buildSingleSelect("Alimentação", ["Nutricionista", "Saudável s/ acomp.", "Irregular"], "alimentacao"),
             _buildTextField("Nível de Estresse (1-10)", "estresse"),
             _buildTextField("Fuma ou Bebe?", "fumante_alcool"),
          ]),

          _buildSection("5. Logística e Preferências", [
             _buildSingleSelect("Frequência Semanal", ["2x", "3x", "4x", "5x", "6x", "Todos os dias"], "freq_semanal"),
             _buildSingleSelect("Tempo Disponível", ["30-40 min", "45-60 min", "+1h"], "tempo_treino"),
             _buildTextField("Horário Preferido", "horario_treino"),
             _buildTextField("O que MAIS gosta na academia?", "gosta_fazer"),
             _buildTextField("O que DETESTA fazer?", "detesta_fazer"),
          ]),

          const SizedBox(height: 20),
          if (widget.isEditable)
            ElevatedButton(
              onPressed: _saveAnamnese,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
              child: const Text("SALVAR FICHA COMPLETA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
        children: children.map((c) => Padding(padding: const EdgeInsets.all(12), child: c)).toList(),
      ),
    );
  }

  Widget _buildTextField(String label, String key) {
    _controllers.putIfAbsent(key, () => TextEditingController());
    return TextFormField(
      controller: _controllers[key],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
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
            _radioOption("Sim", true, key),
            _radioOption("Não", false, key),
          ],
        )
      ],
    );
  }

  Widget _buildYesNoWithText(String question, String key, String ifYesLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildYesNo(question, key),
        if (_formData[key] == true) _buildTextField(ifYesLabel, "${key}_detalhe"),
      ],
    );
  }

  Widget _radioOption(String label, bool value, String key) {
    return Row(
      children: [
        Radio<bool>(
          value: value,
          groupValue: _formData[key],
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _formData[key] = v),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 15),
      ],
    );
  }
  
  Widget _buildSingleSelect(String title, List<String> options, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            return ChoiceChip(
              label: Text(opt),
              selected: _formData[key] == opt,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.black26,
              labelStyle: TextStyle(color: _formData[key] == opt ? Colors.white : Colors.white70),
              onSelected: (selected) => setState(() => _formData[key] = selected ? opt : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMultiSelect(String title, List<String> options) {
    // Implementação simplificada. No ideal, seria um Map<String, bool>
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final key = "check_${opt.toLowerCase()}";
            return FilterChip(
              label: Text(opt),
              selected: _formData[key] == true,
              selectedColor: AppColors.secondary.withOpacity(0.5),
              checkmarkColor: Colors.black,
              backgroundColor: Colors.black26,
              onSelected: (val) => setState(() => _formData[key] = val),
            );
          }).toList(),
        ),
      ],
    );
  }
}
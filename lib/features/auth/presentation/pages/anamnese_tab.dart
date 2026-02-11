import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importante para verificar quem é
import '../../../../core/theme/app_colors.dart';
// IMPORTANTE: Importe o widget de notas que criamos
import '../../../../core/widgets/professor_notes_widget.dart'; 

class AnamneseTab extends StatefulWidget {
  final String studentId;
  final bool isEditable; // Se os campos GERAIS são editáveis

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
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Limpeza dos controllers para evitar vazamento de memória
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('medical')
          .doc('anamnese')
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _formData.addAll(doc.data()!);
          
          // --- CORREÇÃO DO BUG DE TEXTO ---
          // Percorre todos os dados. Se for String, atualiza o controller correspondente.
          _formData.forEach((key, value) {
            if (value is String) {
              // Se o controller já existe, atualiza o texto. Se não, cria.
              if (_controllers.containsKey(key)) {
                _controllers[key]!.text = value;
              } else {
                _controllers[key] = TextEditingController(text: value);
              }
            }
          });
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar anamnese: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAnamnese() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Salva o texto dos controllers normais no map
      _controllers.forEach((key, controller) {
        _formData[key] = controller.text;
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('medical')
          .doc('anamnese')
          .set(_formData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ficha salva com sucesso! ✅"), backgroundColor: AppColors.success)
        );
        // Remove o foco para esconder o teclado
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- ÁREA DO PERSONAL (WIDGET GLOBAL) ---
          // Ele já cuida de aparecer só para o professor e salvar na raiz
          ProfessorNotesWidget(studentId: widget.studentId),

          const SizedBox(height: 10),

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

          _buildSection("3. Saúde e Triagem", [
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
          
          // Botão de Salvar
          ElevatedButton(
            onPressed: _saveAnamnese,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary, 
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text("SALVAR FICHA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconColor: AppColors.secondary,
          collapsedIconColor: Colors.white54,
          children: children.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: c)).toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        enabled: widget.isEditable, 
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondary)),
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
          activeColor: AppColors.secondary,
          onChanged: widget.isEditable ? (v) => setState(() => _formData[key] = v) : null,
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
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = _formData[key] == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: AppColors.secondary,
              backgroundColor: Colors.black26,
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              onSelected: widget.isEditable ? (selected) => setState(() => _formData[key] = selected ? opt : null) : null,
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
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final key = "check_${opt.toLowerCase()}";
            final isSelected = _formData[key] == true;
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: AppColors.secondary.withOpacity(0.8),
              checkmarkColor: Colors.black,
              backgroundColor: Colors.black26,
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
              onSelected: widget.isEditable ? (val) => setState(() => _formData[key] = val) : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
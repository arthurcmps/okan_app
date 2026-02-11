import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
// IMPORTANTE: Importe o widget de notas
import '../../../../core/widgets/professor_notes_widget.dart';

class AssessmentsTab extends StatelessWidget {
  final String studentId;

  const AssessmentsTab({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_chart, color: Colors.black),
        label: const Text("Nova Avaliação", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddAssessmentModal(context),
      ),
      body: Column(
        children: [
          // --- NOTAS GLOBAIS DO PROFESSOR (Sincronizadas com a outra aba) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ProfessorNotesWidget(studentId: studentId),
          ),

          // --- LISTA DE AVALIAÇÕES ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(studentId)
                  .collection('assessments')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("Nenhuma avaliação registrada.", style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['date'] is Timestamp) 
                        ? (data['date'] as Timestamp).toDate() 
                        : DateTime.tryParse(data['date'].toString()) ?? DateTime.now();

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        iconColor: AppColors.secondary,
                        collapsedIconColor: Colors.white70,
                        title: Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${data['weight']}kg  |  BF: ${data['bodyFatPercentage'] ?? '-'}%  |  ${data['generalRating'] ?? ''}", 
                          style: const TextStyle(color: AppColors.secondary)
                        ),
                        children: [
                          _buildSectionHeader("Medidas Corporais"),
                          _buildDetailRow("Peso", "${data['weight']} kg"),
                          _buildDetailRow("Altura", "${data['height']} cm"),
                          _buildDetailRow("Pescoço", "${data['neck'] ?? '-'} cm"),
                          _buildDetailRow("Ombros", "${data['shoulders'] ?? '-'} cm"),
                          _buildDetailRow("Tórax", "${data['chest'] ?? '-'} cm"),
                          _buildDetailRow("Cintura", "${data['waist'] ?? '-'} cm"),
                          _buildDetailRow("Abdômen", "${data['abdomen'] ?? '-'} cm"),
                          _buildDetailRow("Quadril", "${data['hips'] ?? '-'} cm"),
                          const Divider(color: Colors.white10),
                          
                          _buildSectionHeader("Membros (Dir / Esq)"),
                          _buildDetailRow("Braço Relaxado", "${data['armRightRelaxed'] ?? '-'} / ${data['armLeftRelaxed'] ?? '-'} cm"),
                          _buildDetailRow("Braço Contraído", "${data['armRightContracted'] ?? '-'} / ${data['armLeftContracted'] ?? '-'} cm"),
                          _buildDetailRow("Antebraço", "${data['forearmRight'] ?? '-'} / ${data['forearmLeft'] ?? '-'} cm"),
                          _buildDetailRow("Coxa Medial", "${data['thighRight'] ?? '-'} / ${data['thighLeft'] ?? '-'} cm"),
                          _buildDetailRow("Panturrilha", "${data['calfRight'] ?? '-'} / ${data['calfLeft'] ?? '-'} cm"),
                          const Divider(color: Colors.white10),

                          _buildSectionHeader("Bioimpedância"),
                          _buildDetailRow("IMC", "${data['imc']?.toStringAsFixed(2) ?? '-'}"),
                          _buildDetailRow("% Gordura", "${data['bodyFatPercentage'] ?? '-'} %"),
                          _buildDetailRow("Massa Gorda", "${data['fatMassKg'] ?? '-'} kg"),
                          _buildDetailRow("Massa Muscular", "${data['muscleMassKg'] ?? '-'} kg"),
                          _buildDetailRow("Gordura Visceral", "${data['visceralFat'] ?? '-'} (1-9)"),
                          _buildDetailRow("Metabolismo Basal", "${data['basalMetabolism'] ?? '-'} Kcal"),
                          _buildDetailRow("Idade Metabólica", "${data['metabolicAge'] ?? '-'} anos"),
                          _buildDetailRow("Água Corporal", "${data['bodyWaterPercentage'] ?? '-'} %"),
                          _buildDetailRow("Massa Óssea", "${data['boneMass'] ?? '-'} kg"),
                          _buildDetailRow("Avaliação Geral", "${data['generalRating'] ?? '-'}"),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showAddAssessmentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _AssessmentForm(studentId: studentId, scrollController: controller),
      ),
    );
  }
}

// --- FORMULÁRIO (Mantido Igual) ---
class _AssessmentForm extends StatefulWidget {
  final String studentId;
  final ScrollController scrollController;
  const _AssessmentForm({required this.studentId, required this.scrollController});

  @override
  State<_AssessmentForm> createState() => _AssessmentFormState();
}

class _AssessmentFormState extends State<_AssessmentForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final Map<String, dynamic> data = {
        'date': FieldValue.serverTimestamp(),
        'generalRating': _values['generalRating'], 
      };
      
      _values.forEach((key, val) {
        if(val.isNotEmpty && key != 'generalRating') {
          data[key] = double.tryParse(val.replaceAll(',', '.')) ?? val;
        }
      });

      if (data['weight'] != null && data['height'] != null) {
        double w = data['weight'];
        double h = data['height']; 
        double hM = h > 3 ? h / 100 : h; 
        double imcCalc = w / (hM * hM);
        data['imc'] = double.parse(imcCalc.toStringAsFixed(2));
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.studentId)
            .collection('assessments')
            .add(data);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.studentId)
            .update({
              'peso': data['weight'], 
              'altura': data['height'],
              'bodyFatPercentage': data['bodyFatPercentage'],
              'imc': data['imc'],
            });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avaliação salva!"), backgroundColor: Colors.green));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
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
              width: 50, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Text("Nova Avaliação Física", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          _sectionTitle("Dados Principais"),
          Row(children: [
            Expanded(child: _input("Peso (kg)", "weight", required: true)),
            const SizedBox(width: 10),
            Expanded(child: _input("Altura (cm)", "height", required: true)),
          ]),

          _sectionTitle("Perimetria (Tronco)"),
          Row(children: [
            Expanded(child: _input("Pescoço", "neck")),
            const SizedBox(width: 10),
            Expanded(child: _input("Ombros", "shoulders")),
          ]),
          Row(children: [
            Expanded(child: _input("Tórax", "chest")),
            const SizedBox(width: 10),
            Expanded(child: _input("Cintura", "waist")),
          ]),
          Row(children: [
            Expanded(child: _input("Abdômen", "abdomen")),
            const SizedBox(width: 10),
            Expanded(child: _input("Quadril", "hips")),
          ]),

          _sectionTitle("Membros Superiores (Dir / Esq)"),
          const Text("Braço Relaxado", style: TextStyle(color: Colors.white54, fontSize: 12)),
          Row(children: [
            Expanded(child: _input("Direito", "armRightRelaxed")),
            const SizedBox(width: 10),
            Expanded(child: _input("Esquerdo", "armLeftRelaxed")),
          ]),
          const Text("Braço Contraído", style: TextStyle(color: Colors.white54, fontSize: 12)),
          Row(children: [
            Expanded(child: _input("Direito", "armRightContracted")),
            const SizedBox(width: 10),
            Expanded(child: _input("Esquerdo", "armLeftContracted")),
          ]),
          const Text("Antebraço", style: TextStyle(color: Colors.white54, fontSize: 12)),
          Row(children: [
            Expanded(child: _input("Direito", "forearmRight")),
            const SizedBox(width: 10),
            Expanded(child: _input("Esquerdo", "forearmLeft")),
          ]),

          _sectionTitle("Membros Inferiores (Dir / Esq)"),
          const Text("Coxa Medial", style: TextStyle(color: Colors.white54, fontSize: 12)),
          Row(children: [
            Expanded(child: _input("Direita", "thighRight")),
            const SizedBox(width: 10),
            Expanded(child: _input("Esquerda", "thighLeft")),
          ]),
          const Text("Panturrilha", style: TextStyle(color: Colors.white54, fontSize: 12)),
          Row(children: [
            Expanded(child: _input("Direita", "calfRight")),
            const SizedBox(width: 10),
            Expanded(child: _input("Esquerda", "calfLeft")),
          ]),

          const Divider(color: Colors.white24, height: 40),
          
          _sectionTitle("Bioimpedância"),
          Row(children: [
            Expanded(child: _input("% Gordura (BF)", "bodyFatPercentage")),
            const SizedBox(width: 10),
            Expanded(child: _input("Massa Gorda (kg)", "fatMassKg")),
          ]),
          Row(children: [
            Expanded(child: _input("Massa Musc. (kg)", "muscleMassKg")),
            const SizedBox(width: 10),
            Expanded(child: _input("Gord. Visceral (1-9)", "visceralFat")),
          ]),
          Row(children: [
            Expanded(child: _input("Metabolismo (Kcal)", "basalMetabolism")),
            const SizedBox(width: 10),
            Expanded(child: _input("Idade Metab.", "metabolicAge")),
          ]),
          Row(children: [
            Expanded(child: _input("Água Corporal %", "bodyWaterPercentage")),
            const SizedBox(width: 10),
            Expanded(child: _input("Massa Óssea (kg)", "boneMass")),
          ]),
          
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Avaliação Geral",
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
            items: ["Ruim", "Bom", "Ótimo"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => _values['generalRating'] = v ?? '',
          ),
          
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary, 
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text("SALVAR AVALIAÇÃO COMPLETA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _input(String label, String key, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        style: const TextStyle(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
          isDense: true,
        ),
        validator: required ? (v) => v!.isEmpty ? 'Obrigatório' : null : null,
        onSaved: (v) => _values[key] = v ?? '',
      ),
    );
  }
}
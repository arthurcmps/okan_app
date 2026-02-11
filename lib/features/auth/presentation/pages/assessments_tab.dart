import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class AssessmentsTab extends StatelessWidget {
  final String studentId;

  const AssessmentsTab({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add_chart, color: Colors.black),
        onPressed: () => _showAddAssessmentModal(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Card(
                color: AppColors.surface,
                child: ExpansionTile(
                  title: Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['weight']}kg  |  BF: ${data['bodyFatPercentage'] ?? '-'}%", style: const TextStyle(color: AppColors.secondary)),
                  children: [
                    _buildDetailRow("Peso", "${data['weight']} kg"),
                    _buildDetailRow("Altura", "${data['height']} m"),
                    _buildDetailRow("IMC", "${data['imc']?.toStringAsFixed(2) ?? '-'}"),
                    const Divider(color: Colors.white10),
                    const Padding(padding: EdgeInsets.all(8), child: Text("Perimetria", style: TextStyle(color: AppColors.primary))),
                    _buildDetailRow("Cintura", "${data['waist'] ?? '-'} cm"),
                    _buildDetailRow("Abdômen", "${data['abdomen'] ?? '-'} cm"),
                    _buildDetailRow("Quadril", "${data['hips'] ?? '-'} cm"),
                    _buildDetailRow("Braço D/E", "${data['armRightContracted']}/${data['armLeftContracted']} cm"),
                    _buildDetailRow("Coxa D/E", "${data['thighRight']}/${data['thighLeft']} cm"),
                    // Adicione mais campos conforme necessário
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddAssessmentModal(BuildContext context) {
    // Para simplificar, vou abrir um modal básico. 
    // Na prática, você criaria um Widget de Formulário gigante igual ao da Anamnese, 
    // mas só com campos numéricos (KeyboardType.number).
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (_, controller) => _AssessmentForm(studentId: studentId, scrollController: controller),
      ),
    );
  }
}

// Formulário Rápido de Avaliação
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
      
      // Converter Strings para Double/Int
      final Map<String, dynamic> data = {
        'date': FieldValue.serverTimestamp(),
      };
      _values.forEach((key, val) {
        if(val.isNotEmpty) data[key] = double.tryParse(val.replaceAll(',', '.'));
      });

      // Calcular IMC automático
      if (data['weight'] != null && data['height'] != null) {
        double h = data['height'];
        data['imc'] = data['weight'] / (h * h);
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.studentId).collection('assessments').add(data);
      if (mounted) Navigator.pop(context);
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
          const Text("Nova Avaliação", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _input("Peso (kg)", "weight", required: true),
          _input("Altura (m)", "height", required: true),
          const Divider(color: Colors.white24, height: 40),
          const Text("Perimetria (cm)", style: TextStyle(color: AppColors.primary)),
          _input("Pescoço", "neck"),
          _input("Ombros", "shoulders"),
          _input("Tórax", "chest"),
          _input("Cintura", "waist"),
          _input("Abdômen", "abdomen"),
          _input("Quadril", "hips"),
          Row(children: [Expanded(child: _input("Braço Dir.", "armRightContracted")), SizedBox(width: 10), Expanded(child: _input("Braço Esq.", "armLeftContracted"))]),
          Row(children: [Expanded(child: _input("Coxa Dir.", "thighRight")), SizedBox(width: 10), Expanded(child: _input("Coxa Esq.", "thighLeft"))]),
          const Divider(color: Colors.white24, height: 40),
          const Text("Bioimpedância", style: TextStyle(color: AppColors.primary)),
          _input("% Gordura (BF)", "bodyFatPercentage"),
          _input("Massa Muscular (kg)", "muscleMassKg"),
          _input("Gordura Visceral (1-9)", "visceralFat"),
          _input("Idade Metabólica", "metabolicAge"),
          
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("SALVAR AVALIAÇÃO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
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
          labelStyle: const TextStyle(color: Colors.white54),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
        validator: required ? (v) => v!.isEmpty ? 'Obrigatório' : null : null,
        onSaved: (v) => _values[key] = v ?? '',
      ),
    );
  }
}
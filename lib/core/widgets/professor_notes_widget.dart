import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart'; // Ajuste o caminho das cores

class ProfessorNotesWidget extends StatefulWidget {
  final String studentId;

  const ProfessorNotesWidget({super.key, required this.studentId});

  @override
  State<ProfessorNotesWidget> createState() => _ProfessorNotesWidgetState();
}

class _ProfessorNotesWidgetState extends State<ProfessorNotesWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;

  // Verifica se sou eu mesmo (Aluno) ou se é o Professor vendo
  bool get _souPersonal {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    return myId != widget.studentId;
  }

  Future<void> _salvarNotas() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
        'teacherNotes': _controller.text, // Campo Global de Notas
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Anotação atualizada!"), backgroundColor: Colors.green),
        );
        FocusScope.of(context).unfocus(); // Fecha teclado
      }
    } catch (e) {
      debugPrint("Erro: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // SEGREDO: Se não for o personal, não mostra NADA (SizedBox.shrink)
    if (!_souPersonal) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.studentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final notasSalvas = data?['teacherNotes'] ?? "";

        // Só atualiza o texto do controller se o usuário NÃO estiver digitando
        // para evitar que o cursor pule enquanto digita
        if (_controller.text.isEmpty && notasSalvas.isNotEmpty) {
           _controller.text = notasSalvas;
        }

        return Card(
          color: const Color(0xFF2A273A), // Fundo escuro destaque
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary, width: 1), // Borda Terracota
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Anotações Privadas (Só você vê)", 
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    if (_isSaving)
                      const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    else
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.white),
                        tooltip: "Salvar Anotação",
                        onPressed: _salvarNotas,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      )
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Evolução, dores relatadas, estratégia de treino...",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/firebase_assessments_repository.dart';
import '../../domain/entities/professor_note_state.dart';
import '../../domain/repositories/assessments_repository.dart';

class ProfessorNotesWidget extends StatefulWidget {
  const ProfessorNotesWidget({
    super.key,
    required this.studentId,
    this.repository,
  });

  final String studentId;
  final AssessmentsRepository? repository;

  @override
  State<ProfessorNotesWidget> createState() => _ProfessorNotesWidgetState();
}

class _ProfessorNotesWidgetState extends State<ProfessorNotesWidget> {
  final TextEditingController _controller = TextEditingController();
  late final AssessmentsRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseAssessmentsRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await _repository.saveProfessorNote(
        studentId: widget.studentId,
        text: _controller.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anotação atualizada!'),
          backgroundColor: Colors.green,
        ),
      );
      FocusScope.of(context).unfocus();
    } catch (error) {
      debugPrint('Erro ao salvar anotação privada: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a anotação.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfessorNoteState>(
      stream: _repository.watchProfessorNote(widget.studentId),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || !state.isVisible) {
          return const SizedBox.shrink();
        }

        if (!_controller.selection.isValid && _controller.text != state.text) {
          _controller.text = state.text;
        } else if (_controller.text.isEmpty && state.text.isNotEmpty) {
          _controller.text = state.text;
        }

        return Card(
          color: const Color(0xFF2A273A),
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anotações privadas do personal',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isSaving)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.white),
                        tooltip: 'Salvar anotação',
                        onPressed: _save,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Evolução, dores relatadas, estratégia de treino...',
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

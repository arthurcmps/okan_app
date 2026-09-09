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
  late Stream<ProfessorNoteState> _noteStream;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseAssessmentsRepository();
    _noteStream = _repository.watchProfessorNote(widget.studentId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
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
          backgroundColor: AppColors.success,
        ),
      );
      FocusScope.of(context).unfocus();
    } catch (error) {
      debugPrint('ProfessorNotesWidget/save: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a anotação.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retryLoading() {
    setState(() {
      _noteStream = _repository.watchProfessorNote(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfessorNoteState>(
      stream: _noteStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildStatusCard(
            key: const ValueKey('professor-notes-loading'),
            child: const Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Carregando anotações privadas')),
              ],
            ),
            announce: true,
          );
        }

        if (snapshot.hasError) {
          return _buildStatusCard(
            key: const ValueKey('professor-notes-error'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Não foi possível carregar as anotações.'),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('professor-notes-retry'),
                    onPressed: _retryLoading,
                    child: const Text('Tentar novamente'),
                  ),
                ),
              ],
            ),
            announce: true,
          );
        }

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
          color: AppColors.surface,
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
                        key: const ValueKey('professor-notes-save'),
                        icon: const Icon(Icons.save, color: Colors.white),
                        tooltip: 'Salvar anotação',
                        onPressed: _save,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  enabled: !_isSaving,
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

  Widget _buildStatusCard({
    required Key key,
    required Widget child,
    bool announce = false,
  }) {
    return Card(
      key: key,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          liveRegion: announce,
          child: child,
        ),
      ),
    );
  }
}

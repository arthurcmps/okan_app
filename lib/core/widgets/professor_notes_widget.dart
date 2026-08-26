import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProfessorNotesWidget extends StatefulWidget {
  final String studentId;

  const ProfessorNotesWidget({super.key, required this.studentId});

  @override
  State<ProfessorNotesWidget> createState() => _ProfessorNotesWidgetState();
}

class _ProfessorNotesWidgetState extends State<ProfessorNotesWidget> {
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _noteRef {
    final uid = _currentUid;

    if (uid == null || uid == widget.studentId) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.studentId)
        .collection('private_notes')
        .doc(uid);
  }

  Future<void> _salvarNotas() async {
    final uid = _currentUid;
    final ref = _noteRef;

    if (uid == null || ref == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.set({
        // Campo de domínio da nota privada; não é o vínculo User v2.
        'personalId': uid,
        'text': _controller.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anotação atualizada!'),
            backgroundColor: Colors.green,
          ),
        );

        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      debugPrint('Erro ao salvar anotação privada: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a anotação.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;

    // O próprio aluno nunca visualiza notas privadas.
    if (uid == null || uid == widget.studentId) {
      return const SizedBox.shrink();
    }

    /*
     * Primeiro confirmamos no vínculo do aluno se o usuário
     * atual é realmente o professor responsável.
     */
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .snapshots(),
      builder: (context, studentSnapshot) {
        if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final studentData = studentSnapshot.data!.data() ?? {};

        final linkedProfessorId =
            studentData['professorId']?.toString() ??
            studentData['personalId']?.toString();

        if (linkedProfessorId != uid) {
          return const SizedBox.shrink();
        }

        final noteRef = _noteRef;

        if (noteRef == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: noteRef.snapshots(),
          builder: (context, noteSnapshot) {
            if (noteSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final noteData = noteSnapshot.data?.data();

            final savedText = noteData?['text']?.toString() ?? '';

            if (!_controller.selection.isValid &&
                _controller.text != savedText) {
              _controller.text = savedText;
            } else if (_controller.text.isEmpty && savedText.isNotEmpty) {
              _controller.text = savedText;
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
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
                            onPressed: _salvarNotas,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText:
                            'Evolução, dores relatadas, estratégia de treino...',
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
      },
    );
  }
}

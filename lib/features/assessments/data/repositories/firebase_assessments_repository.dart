import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/anamnese_record.dart';
import '../../domain/entities/physical_assessment.dart';
import '../../domain/entities/professor_note_state.dart';
import '../../domain/repositories/assessments_repository.dart';

class FirebaseAssessmentsRepository implements AssessmentsRepository {
  FirebaseAssessmentsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<AnamneseRecord> loadAnamnese(String studentId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(studentId)
        .collection('medical')
        .doc('anamnese')
        .get();

    return AnamneseRecord(
      values: Map<String, dynamic>.from(
        snapshot.data() ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<void> saveAnamnese({
    required String studentId,
    required Map<String, dynamic> values,
  }) {
    return _firestore
        .collection('users')
        .doc(studentId)
        .collection('medical')
        .doc('anamnese')
        .set(
          Map<String, dynamic>.from(values),
          SetOptions(merge: true),
        );
  }

  @override
  Stream<List<PhysicalAssessment>> watchAssessments(
    String studentId, {
    bool descending = true,
  }) {
    return _firestore
        .collection('users')
        .doc(studentId)
        .collection('assessments')
        .orderBy('date', descending: descending)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final raw = document.data();
            final date = _dateFrom(raw['date']) ?? DateTime.now();
            final values = Map<String, dynamic>.from(raw)..['date'] = date;

            return PhysicalAssessment(
              id: document.id,
              date: date,
              values: values,
            );
          }).toList(growable: false),
        );
  }

  @override
  Future<void> addAssessment({
    required String studentId,
    required Map<String, dynamic> values,
  }) async {
    final userRef = _firestore.collection('users').doc(studentId);
    final assessmentRef = userRef.collection('assessments').doc();
    final payload = Map<String, dynamic>.from(values)
      ..['date'] = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(assessmentRef, payload);
    batch.update(userRef, {
      'peso': values['weight'],
      'altura': values['height'],
      'bodyFatPercentage': values['bodyFatPercentage'],
      'imc': values['imc'],
    });
    await batch.commit();
  }

  @override
  Stream<ProfessorNoteState> watchProfessorNote(String studentId) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid == studentId) {
      return Stream<ProfessorNoteState>.value(
        const ProfessorNoteState.hidden(),
      );
    }

    late StreamController<ProfessorNoteState> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? studentSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? noteSub;

    Future<void> handleStudent(
      DocumentSnapshot<Map<String, dynamic>> studentSnapshot,
    ) async {
      await noteSub?.cancel();
      noteSub = null;

      if (!studentSnapshot.exists) {
        controller.add(const ProfessorNoteState.hidden());
        return;
      }

      final data = studentSnapshot.data() ?? const <String, dynamic>{};
      final linkedProfessionalId =
          _stringValue(data['professorId']) ??
          _stringValue(data['personalId']);

      if (linkedProfessionalId != currentUid) {
        controller.add(const ProfessorNoteState.hidden());
        return;
      }

      noteSub = _firestore
          .collection('users')
          .doc(studentId)
          .collection('private_notes')
          .doc(currentUid)
          .snapshots()
          .listen(
            (noteSnapshot) => controller.add(
              ProfessorNoteState(
                isVisible: true,
                text: _stringValue(noteSnapshot.data()?['text']) ?? '',
              ),
            ),
            onError: controller.addError,
          );
    }

    controller = StreamController<ProfessorNoteState>(
      onListen: () {
        studentSub = _firestore
            .collection('users')
            .doc(studentId)
            .snapshots()
            .listen(
              (snapshot) => unawaited(handleStudent(snapshot)),
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await studentSub?.cancel();
        await noteSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> saveProfessorNote({
    required String studentId,
    required String text,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid == studentId) {
      throw StateError('Usuário sem permissão para salvar nota privada.');
    }

    final student = await _firestore.collection('users').doc(studentId).get();
    final data = student.data() ?? const <String, dynamic>{};
    final linkedProfessionalId =
        _stringValue(data['professorId']) ??
        _stringValue(data['personalId']);

    if (linkedProfessionalId != currentUid) {
      throw StateError('Usuário sem vínculo profissional com este aluno.');
    }

    await _firestore
        .collection('users')
        .doc(studentId)
        .collection('private_notes')
        .doc(currentUid)
        .set({
          'personalId': currentUid,
          'text': text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _stringValue(dynamic value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

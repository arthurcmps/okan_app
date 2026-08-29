import '../entities/anamnese_record.dart';
import '../entities/physical_assessment.dart';
import '../entities/professor_note_state.dart';

abstract interface class AssessmentsRepository {
  Future<AnamneseRecord> loadAnamnese(String studentId);

  Future<void> saveAnamnese({
    required String studentId,
    required Map<String, dynamic> values,
  });

  Stream<List<PhysicalAssessment>> watchAssessments(
    String studentId, {
    bool descending = true,
  });

  Future<void> addAssessment({
    required String studentId,
    required Map<String, dynamic> values,
  });

  Stream<ProfessorNoteState> watchProfessorNote(String studentId);

  Future<void> saveProfessorNote({
    required String studentId,
    required String text,
  });
}

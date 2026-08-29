import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/task_item.dart';
import '../../domain/repositories/tasks_repository.dart';

class FirebaseTasksRepository implements TasksRepository {
  FirebaseTasksRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Tarefa>> watchTasks(String userId) {
    return _firestore
        .collection('tarefas')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final tasks = snapshot.docs
                .map(
                  (document) => _taskFrom(
                    document.id,
                    document.data(),
                  ),
                )
                .toList(growable: false);

            tasks.sort(
              (a, b) => b.dataCriacao.compareTo(a.dataCriacao),
            );

            return tasks;
          },
        );
  }

  @override
  Future<void> addTask({
    required String userId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return;

    await _firestore.collection('tarefas').add({
      'titulo': normalizedTitle,
      'concluida': false,
      'userId': userId,
      'dataCriacao': FieldValue.serverTimestamp(),
      'dataConclusao': null,
    });
  }

  @override
  Future<void> setTaskCompleted({
    required String taskId,
    required bool completed,
  }) {
    return _firestore.collection('tarefas').doc(taskId).update({
      'concluida': completed,
      'dataConclusao': completed ? FieldValue.serverTimestamp() : null,
    });
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _firestore.collection('tarefas').doc(taskId).delete();
  }

  @override
  Future<void> restoreTask({
    required String userId,
    required Tarefa task,
  }) {
    return _firestore.collection('tarefas').add({
      'titulo': task.titulo,
      'concluida': task.concluida,
      'userId': userId,
      'dataCriacao': FieldValue.serverTimestamp(),
      'dataConclusao': task.dataConclusao == null
          ? null
          : Timestamp.fromDate(task.dataConclusao!),
    });
  }

  @override
  Future<void> updateTitle({
    required String taskId,
    required String title,
  }) {
    return _firestore.collection('tarefas').doc(taskId).update({
      'titulo': title.trim(),
    });
  }

  static Tarefa _taskFrom(
    String id,
    Map<String, dynamic> data,
  ) {
    return Tarefa(
      id: id,
      titulo: _stringOrFallback(data['titulo'], 'Sem Título'),
      concluida: data['concluida'] == true,
      userId: _stringOrFallback(data['userId'], ''),
      dataCriacao:
          _dateFrom(data['dataCriacao']) ??
          _dateFrom(data['data']) ??
          DateTime.now(),
      dataConclusao: _dateFrom(data['dataConclusao']),
    );
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _stringOrFallback(dynamic value, String fallback) {
    if (value is! String) return fallback;
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

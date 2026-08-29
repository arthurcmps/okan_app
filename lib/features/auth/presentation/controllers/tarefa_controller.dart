import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../tasks/data/repositories/firebase_tasks_repository.dart';
import '../../../tasks/domain/repositories/tasks_repository.dart';
import '../../data/models/tarefa_model.dart';

class TarefaController extends ChangeNotifier {
  TarefaController({TasksRepository? repository})
    : _repository = repository ?? FirebaseTasksRepository();

  final TasksRepository _repository;

  List<Tarefa> tarefas = [];
  bool isLoading = false;
  Tarefa? ultimaTarefaRemovida;

  StreamSubscription<List<Tarefa>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void iniciarEscuta() {
    _subscription?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      tarefas = [];
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    _subscription = _repository.watchTasks(user.uid).listen(
      (tasks) {
        tarefas = tasks;
        isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        isLoading = false;
        debugPrint('TarefaController/iniciarEscuta: $error');
        notifyListeners();
      },
    );
  }

  Future<void> adicionar(String titulo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('TarefaController/adicionar: usuário não autenticado.');
      return;
    }

    try {
      await _repository.addTask(
        userId: user.uid,
        title: titulo,
      );
    } catch (error) {
      debugPrint('TarefaController/adicionar: $error');
      rethrow;
    }
  }

  Future<void> alternarConclusao(Tarefa tarefa) async {
    final previousCompleted = tarefa.concluida;
    final previousCompletionDate = tarefa.dataConclusao;
    final nextCompleted = !previousCompleted;

    tarefa.concluida = nextCompleted;
    tarefa.dataConclusao = nextCompleted ? DateTime.now() : null;
    notifyListeners();

    try {
      await _repository.setTaskCompleted(
        taskId: tarefa.id,
        completed: nextCompleted,
      );
    } catch (error) {
      tarefa.concluida = previousCompleted;
      tarefa.dataConclusao = previousCompletionDate;
      notifyListeners();
      debugPrint('TarefaController/alternarConclusao: $error');
      rethrow;
    }
  }

  Future<void> remover(String id) async {
    try {
      ultimaTarefaRemovida = tarefas.firstWhere((task) => task.id == id);
    } catch (_) {
      ultimaTarefaRemovida = null;
    }

    await _repository.deleteTask(id);
  }

  Future<void> desfazerExclusao(Tarefa tarefaRef) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _repository.restoreTask(
      userId: user.uid,
      task: tarefaRef,
    );
  }

  Future<void> atualizarTitulo(Tarefa tarefa, String novoTitulo) {
    return _repository.updateTitle(
      taskId: tarefa.id,
      title: novoTitulo,
    );
  }
}

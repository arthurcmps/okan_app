import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importando o modelo da pasta correta
import '../../data/models/tarefa_controller.dart';

class TarefaController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Tarefa> tarefas = [];

  // Inicia a escuta em tempo real do Firestore
  void iniciarEscuta() {
    _db.collection('tarefas').snapshots().listen((snapshot) {
      tarefas = snapshot.docs.map((doc) {
        return Tarefa.fromMap(doc.id, doc.data());
      }).toList();
      notifyListeners(); // Atualiza a tela
    });
  }

  Future<void> adicionar(String titulo) async {
    await _db.collection('tarefas').add({
      'titulo': titulo,
      'concluida': false,
    });
  }

  Future<void> alternarConclusao(Tarefa tarefa) async {
    await _db.collection('tarefas').doc(tarefa.id).update({
      'concluida': !tarefa.concluida,
    });
  }

  Future<void> remover(String id) async {
    await _db.collection('tarefas').doc(id).delete();
  }
}
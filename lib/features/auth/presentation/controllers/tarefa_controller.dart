import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importando o modelo da pasta correta
import '../../data/models/tarefa_controller.dart';

class TarefaController extends ChangeNotifier {
  // Conexão com o Banco de Dados
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Lista local que a tela vai "observar"
  List<Tarefa> tarefas = [];

  // --- 1. LEITURA EM TEMPO REAL (REALTIME) ---
  // Este método fica vigiando o banco. Se mudar lá, muda aqui na hora.
  void iniciarEscuta() {
    _db.collection('tarefas').snapshots().listen((snapshot) {
      tarefas = snapshot.docs.map((doc) {
        return Tarefa.fromMap(doc.id, doc.data());
      }).toList();
      
      notifyListeners(); // AVISA A TELA: "Mudou algo, redesenhe!"
    });
  }

  // --- 2. ADICIONAR (CREATE) ---
  Future<void> adicionar(String titulo) async {
    await _db.collection('tarefas').add({
      'titulo': titulo,
      'concluida': false,
      // Dica: Futuramente você pode adicionar um campo 'dataCriacao' aqui para ordenar
    });
  }

  // --- 3. ALTERNAR STATUS (UPDATE) ---
  // Marca como feito ou pendente
  Future<void> alternarConclusao(Tarefa tarefa) async {
    await _db.collection('tarefas').doc(tarefa.id).update({
      'concluida': !tarefa.concluida,
    });
  }

  // --- 4. REMOVER (DELETE) ---
  Future<void> remover(String id) async {
    await _db.collection('tarefas').doc(id).delete();
  }

  // --- 5. EDITAR TÍTULO (NOVO) ---
  // Permite corrigir o nome da tarefa
  Future<void> atualizarTitulo(Tarefa tarefa, String novoTitulo) async {
    await _db.collection('tarefas').doc(tarefa.id).update({
      'titulo': novoTitulo,
    });
  }

  // --- 6. DESFAZER EXCLUSÃO (NOVO) ---
  // Readiciona uma tarefa que foi apagada recentemente
  Future<void> desfazerExclusao(Tarefa tarefa) async {
    await _db.collection('tarefas').add({
      'titulo': tarefa.titulo,
      'concluida': tarefa.concluida,
    });
  }
}
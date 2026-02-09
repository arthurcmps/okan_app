import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/tarefa_model.dart';

class TarefaController extends ChangeNotifier {
  List<Tarefa> tarefas = [];
  bool isLoading = false;
  Tarefa? ultimaTarefaRemovida;
  
  // Controle da conexão com o banco
  StreamSubscription? _subscription;

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

    // Escuta apenas as tarefas do usuário logado
    _subscription = FirebaseFirestore.instance
        .collection('tarefas')
        .where('userId', isEqualTo: user.uid)
        // .orderBy('dataCriacao', descending: true) // REATIVE APÓS CRIAR O ÍNDICE
        .snapshots()
        .listen((snapshot) {
      
      tarefas = snapshot.docs
          .map((doc) => Tarefa.fromMap(doc.id, doc.data()))
          .toList();

      // Ordenação manual (enquanto não tem índice)
      tarefas.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));

      isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint("ERRO NO STREAM: $e");
    });
  }

  // --- ADICIONAR (BLINDADO) ---
  Future<void> adicionar(String titulo) async {
    print("--- INICIANDO ADIÇÃO DE TAREFA ---");
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("ERRO: Usuário não identificado.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tarefas').add({
        'titulo': titulo,
        'concluida': false,
        'userId': user.uid,
        'dataCriacao': FieldValue.serverTimestamp(),
        'dataConclusao': null,
      });
      print("SUCESSO: Tarefa salva no Firebase!");
    } catch (e) {
      print("ERRO CRÍTICO AO SALVAR: $e");
    }
  }

  // --- ALTERNAR STATUS ---
  Future<void> alternarConclusao(Tarefa tarefa) async {
    final novoEstado = !tarefa.concluida;
    
    // Atualiza na tela imediatamente (Otimista)
    tarefa.concluida = novoEstado;
    if (novoEstado) {
      tarefa.dataConclusao = DateTime.now();
    } else {
      tarefa.dataConclusao = null;
    }
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('tarefas')
          .doc(tarefa.id)
          .update({
            'concluida': novoEstado,
            'dataConclusao': novoEstado ? FieldValue.serverTimestamp() : null
          });
    } catch (e) {
      print("Erro ao atualizar status: $e");
      // Reverte se der erro (opcional)
    }
  }

  // --- REMOVER ---
  Future<void> remover(String id) async {
    try {
      ultimaTarefaRemovida = tarefas.firstWhere((t) => t.id == id);
    } catch (_) {}
    await FirebaseFirestore.instance.collection('tarefas').doc(id).delete();
  }

  // --- DESFAZER ---
  Future<void> desfazerExclusao(Tarefa tarefaRef) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('tarefas').add({
      'titulo': tarefaRef.titulo,
      'concluida': tarefaRef.concluida,
      'userId': user.uid,
      'dataCriacao': FieldValue.serverTimestamp(),
      'dataConclusao': tarefaRef.dataConclusao != null ? Timestamp.fromDate(tarefaRef.dataConclusao!) : null,
    });
  }

  // --- EDITAR ---
  Future<void> atualizarTitulo(Tarefa tarefa, String novoTitulo) async {
    await FirebaseFirestore.instance
        .collection('tarefas')
        .doc(tarefa.id)
        .update({'titulo': novoTitulo});
  }
}
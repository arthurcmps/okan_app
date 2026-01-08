import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- CADASTRO ATUALIZADO ---
  Future<String?> cadastrarUsuario({
    required String nome,
    required String email,
    required String password,
    required String tipo, // 'personal' ou 'aluno'
    DateTime? dataNascimento, // <--- NOVO CAMPO ADICIONADO
  }) async {
    try {
      // 1. Cria o usuário no Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Salva os dados no Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'nome': nome,
        'email': email,
        'tipo': tipo,
        'dataNascimento': dataNascimento, // <--- SALVANDO NO BANCO
        'criadoEm': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') return 'A senha é muito fraca.';
      if (e.code == 'email-already-in-use') return 'Este e-mail já está em uso.';
      return 'Erro no Firebase: ${e.message}';
    } catch (e) {
      return 'Erro desconhecido: $e';
    }
  }

  // --- LOGIN ---
  Future<String?> loginUsuario({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return 'E-mail ou senha incorretos.';
      }
      if (e.code == 'wrong-password') return 'Senha incorreta.';
      if (e.code == 'invalid-email') return 'E-mail inválido.';
      return 'Erro de login: ${e.message}';
    } catch (e) {
      return 'Erro: $e';
    }
  }

  // --- DESLOGAR ---
  Future<void> deslogar() async {
    await _auth.signOut();
  }

  // --- DESCOBRIR TIPO DE USUÁRIO ---
  Future<String> obterTipoUsuario() async {
    final user = _auth.currentUser;
    if (user == null) return 'aluno';
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      // Tenta pegar 'tipo' (padrão novo) ou 'role' (se tiver algum antigo)
      return doc.data()?['tipo'] ?? doc.data()?['role'] ?? 'aluno'; 
    } catch (e) {
      return 'aluno';
    }
  }
  
  User? get usuarioAtual => _auth.currentUser;
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- CADASTRO (Agora com TIPO: Personal ou Aluno) ---
  Future<String?> cadastrarUsuario({
    required String nome,
    required String email,
    required String password,
    required String tipo, // 'personal' ou 'aluno'
  }) async {
    try {
      // 1. Cria o usuário no sistema de Login do Firebase
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Cria a ficha do usuário no Banco de Dados (Firestore)
      // É aqui que salvamos se ele é PERSONAL ou ALUNO
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'nome': nome,
        'email': email,
        'tipo': tipo, // <--- O CAMPO IMPORTANTE
        'criadoEm': FieldValue.serverTimestamp(),
      });

      return null; // Retorna null se deu tudo certo
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
      return null; // Sucesso
    } on FirebaseAuthException catch (e) {
      // Traduzindo erros comuns para português
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

  // --- DESCOBRIR QUEM É O USUÁRIO ---
  // Essa função vai ajudar a Home a decidir o que mostrar
  Future<String> obterTipoUsuario() async {
    final user = _auth.currentUser;
    if (user == null) return 'erro';
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      // Retorna 'personal', 'aluno' ou 'aluno' se não tiver nada
      return doc.data()?['tipo'] ?? 'aluno'; 
    } catch (e) {
      return 'aluno'; // Na dúvida, trata como aluno
    }
  }
  
  // Pega o usuário atual logado
  User? get usuarioAtual => _auth.currentUser;
}
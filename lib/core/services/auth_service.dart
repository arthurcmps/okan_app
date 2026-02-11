import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- CADASTRO POR E-MAIL (Com Data de Nascimento) ---
  Future<String?> cadastrarUsuario({
    required String nome,
    required String email,
    required String password,
    required String tipo, // 'personal' ou 'aluno'
    required DateTime? dataNascimento, // <--- OBRIGATÓRIO (pode ser nulo se vier de outra fonte, mas aqui pedimos)
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
        'name': nome, // Padronizei para 'name' (igual ao Google)
        'email': email,
        'tipo': tipo,
        'birthDate': dataNascimento, // Salva como Timestamp
        'createdAt': FieldValue.serverTimestamp(),
        // Campos padrão para evitar erros no perfil
        if (tipo == 'aluno') ...{
           'peso': '--',
           'altura': '--',
           'objetivo': 'Definir',
           'freq_semanal': '3x',
        }
      });

      // Atualiza o nome no Auth
      await userCredential.user!.updateDisplayName(nome);

      return null; // Sucesso
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') return 'A senha é muito fraca.';
      if (e.code == 'email-already-in-use') return 'Este e-mail já está em uso.';
      return 'Erro no Firebase: ${e.message}';
    } catch (e) {
      return 'Erro desconhecido: $e';
    }
  }

  // --- LOGIN POR E-MAIL ---
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
      return 'Erro de login: ${e.message}';
    } catch (e) {
      return 'Erro: $e';
    }
  }

  // --- LOGIN COM GOOGLE ---
  Future<String?> entrarComGoogle() async {
    try {
      // 1. Inicia o fluxo do Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Login cancelado pelo usuário.";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 2. Credenciais para o Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Loga no Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 4. Verifica se o usuário já existe no Firestore
        final docSnapshot = await _firestore.collection('users').doc(user.uid).get();

        if (!docSnapshot.exists) {
          // SE É NOVO USUÁRIO: Cria o doc básico (SEM DATA DE NASCIMENTO)
          // O ProfilePage vai detectar que 'birthDate' é null e pedir para preencher.
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? "Usuário Google",
            'email': user.email,
            'photoUrl': user.photoURL,
            'tipo': 'aluno', // Padrão inicial
            'birthDate': null, // <--- VEM VAZIO DO GOOGLE
            'createdAt': FieldValue.serverTimestamp(),
            'peso': '--',
            'altura': '--',
            'objetivo': 'Definir',
            'freq_semanal': '3x',
          });
        }
      }
      return null; // Sucesso
    } catch (e) {
      return "Erro no Google Login: $e";
    }
  }

  // --- DESLOGAR ---
  Future<void> deslogar() async {
    await _googleSignIn.signOut(); // Importante deslogar do Google também
    await _auth.signOut();
  }

  User? get usuarioAtual => _auth.currentUser;
}
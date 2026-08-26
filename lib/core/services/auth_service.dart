import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../../features/auth/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Construtor para forçar a persistência local
  AuthService() {
    _configurarPersistencia();
  }

  Future<void> _configurarPersistencia() async {
    try {
      // kIsWeb é usado porque a persistência na web (se você compilar para web no futuro) é diferente
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      } else {
        // No mobile (Android/iOS), LOCAL é o padrão, mas chamamos explicitamente
        // para contornar bugs do SDK em algumas versões.
        await _auth.setPersistence(Persistence.LOCAL);
      }
    } catch (e) {
      debugPrint("Erro ao configurar persistência: $e");
    }
  }

  // --- CADASTRO POR E-MAIL (Com Data de Nascimento) ---
  Future<String?> cadastrarUsuario({
    required String nome,
    required String email,
    required String password,
    required String role,
    required DateTime? dataNascimento,
  }) async {
    try {
      if (role != UserRoles.aluno && role != UserRoles.professor) {
        return 'Perfil de usuário inválido.';
      }

      final normalizedEmail = email.trim().toLowerCase();
      final memberType = role == UserRoles.professor
          ? UserMemberTypes.professor
          : UserMemberTypes.aluno;

      // 1. Cria o usuário no Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

      final user = userCredential.user!;

      // 2. Cria o User v2 no Firestore.
      //
      // Os campos de fitness continuam temporariamente
      // na raiz para compatibilidade com telas legadas.
      await _firestore.collection('users').doc(user.uid).set({
        'schemaVersion': UserModel.currentSchemaVersion,
        'uid': user.uid,
        'name': nome.trim(),
        'email': normalizedEmail,
        'role': role,
        'memberType': memberType,
        'photoUrl': null,
        'academyId': null,
        'professorId': null,
        'birthDate': dataNascimento,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        if (role == UserRoles.aluno) ...{
          'peso': '--',
          'altura': '--',
          'objetivo': 'Definir',
          'freq_semanal': '3x',
        },
      });

      await user.updateDisplayName(nome.trim());

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'A senha é muito fraca.';
      }

      if (e.code == 'email-already-in-use') {
        return 'Este e-mail já está em uso.';
      }

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
      await _configurarPersistencia(); // Reforça a persistência antes de logar
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
      await _configurarPersistencia(); // Reforça a persistência antes de logar

      // 1. Inicia o fluxo do Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Login cancelado pelo usuário.";

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 2. Credenciais para o Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Loga no Firebase
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 4. Verifica se o usuário já existe no Firestore
        final docSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!docSnapshot.exists) {
          final normalizedEmail = user.email?.trim().toLowerCase();

          await _firestore.collection('users').doc(user.uid).set({
            'schemaVersion': UserModel.currentSchemaVersion,
            'uid': user.uid,
            'name': user.displayName ?? "Usuário Google",
            'email': normalizedEmail,
            'role': UserRoles.aluno,
            'memberType': UserMemberTypes.aluno,
            'photoUrl': user.photoURL,
            'academyId': null,
            'professorId': null,
            'birthDate': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),

            // Compatibilidade temporária.
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

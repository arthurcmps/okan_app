import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <--- Importante
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importante
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Para mostrar carregamento no botão Google

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIN COM EMAIL E SENHA ---
  Future<void> _fazerLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );

      } on FirebaseAuthException catch (e) {
        String mensagemErro = 'Erro ao fazer login.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          mensagemErro = 'E-mail ou senha incorretos.';
        } else if (e.code == 'invalid-email') {
           mensagemErro = 'Formato de e-mail inválido.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- LOGIN COM GOOGLE (NOVO) ---
  Future<void> _fazerLoginGoogle() async {
    setState(() => _isLoading = true);

    try {
      // 1. Iniciar fluxo do Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      // Se o usuário cancelou a janelinha
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obter credenciais
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Fazer login no Firebase
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      final user = userCredential.user;

      // 4. VERIFICAÇÃO INTELIGENTE DO FIRESTORE
      // Se for o primeiro acesso via Google, precisamos criar o perfil no banco
      // para que a tela de Perfil funcione (peso, idade, etc).
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Cria o documento padrão
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? "Aluno Google",
            'email': user.email,
            'photoUrl': user.photoURL, // Salva a foto do Google!
            'role': 'aluno',
            'createdAt': FieldValue.serverTimestamp(),
            'weight': 0.0,
            'objectives': 'Definir objetivo',
            // Não temos data de nascimento pelo Google, fica vazio para editar depois
          });
        }
      }

      if (!mounted) return;
      
      // Sucesso
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no Google: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  'Bem-vindo de volta!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 48),

                // CAMPOS DE EMAIL E SENHA
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || !val.contains('@')) ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (val) => (val == null || val.length < 6) ? 'Senha curta' : null,
                ),
                
                const SizedBox(height: 24),

                // BOTÃO ENTRAR
                FilledButton(
                  onPressed: _isLoading ? null : _fazerLogin,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                
                const SizedBox(height: 16),
                
                // --- DIVISOR "OU" ---
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OU")),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // --- BOTÃO GOOGLE ---
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fazerLoginGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  // Se quiser o logo colorido, pode usar Image.asset, mas vamos usar um Icon simples por enquanto
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red), 
                  label: const Text("Entrar com Google", style: TextStyle(fontSize: 16, color: Colors.black87)),
                ),

                const SizedBox(height: 24),

                // LINK CADASTRO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Não tem uma conta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text('Cadastre-se'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
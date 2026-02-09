import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'register_page.dart';

// IMPORTANTE: Ajuste este caminho para onde você salvou o app_colors.dart
// Se estiver na pasta core/theme/, o caminho relativo deve ser este:
import '../../../../../core/theme/app_colors.dart';

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
  bool _isLoading = false;

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
          MaterialPageRoute(builder: (context) => const HomePage()),
        );

      } on FirebaseAuthException catch (e) {
        String mensagemErro = 'Erro ao fazer login.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          mensagemErro = 'E-mail ou senha incorretos.';
        } else if (e.code == 'invalid-email') {
           mensagemErro = 'Formato de e-mail inválido.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- LOGIN COM GOOGLE ---
  Future<void> _fazerLoginGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? "Aluno Google",
            'email': user.email,
            'photoUrl': user.photoURL,
            'role': 'aluno',
            'createdAt': FieldValue.serverTimestamp(),
            'weight': 0.0,
            'objectives': 'Definir objetivo',
          });
        }
      }

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no Google: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background vem do tema global, mas garantimos aqui
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ÍCONE LOGO
                const Icon(
                  Icons.fitness_center, 
                  size: 80, 
                  color: AppColors.primary
                ),
                const SizedBox(height: 24),
                
                // TÍTULO
                Text(
                  'Bem-vindo ao Okan',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conecte corpo e mente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSub),
                ),
                const SizedBox(height: 48),

                // CAMPO EMAIL
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textMain), // Texto digitado branco
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) => (val == null || !val.contains('@')) ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                
                // CAMPO SENHA
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: AppColors.textMain),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                
                const SizedBox(height: 16),
                
                // DIVISOR
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16), 
                      child: Text("OU", style: TextStyle(color: AppColors.textSub))
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),

                // BOTÃO GOOGLE
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fazerLoginGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.textSub), // Borda cinza
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red), 
                  label: const Text("Entrar com Google", style: TextStyle(fontSize: 16, color: AppColors.textMain)),
                ),

                const SizedBox(height: 24),

                // LINK CADASTRO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Não tem uma conta?', style: TextStyle(color: AppColors.textSub)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text('Cadastre-se', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
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
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'register_page.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final erro = await _authService.loginUsuario(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (erro == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _fazerLoginGoogle() async {
    setState(() => _isLoading = true);
    final erro = await _authService.entrarComGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (erro == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      } else {
        if (erro != "Login cancelado.") {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: AppColors.error));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                Image.asset(
                  'assets/images/logo_okan.png',
                  height: 120, // Altura balanceada
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.fitness_center, size: 80, color: AppColors.primary);
                  },
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Bem-vindo ao Okan',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800, // Mais peso
                        color: AppColors.textMain,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sua essência, sua força.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSub, letterSpacing: 1.0),
                ),
                const SizedBox(height: 48),

                // EMAIL
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) => (val == null || !val.contains('@')) ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                
                // SENHA
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.textSub),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (val) => (val == null || val.length < 6) ? 'Senha curta' : null,
                ),
                
                const SizedBox(height: 32),

                // BOTÃO ENTRAR (Neon com texto preto)
                FilledButton(
                  onPressed: _isLoading ? null : _fazerLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)) 
                    : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                
                const SizedBox(height: 20),
                
                // DIVISOR
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white10)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OU", style: TextStyle(color: AppColors.textSub, fontSize: 12))),
                    Expanded(child: Divider(color: Colors.white10)),
                  ],
                ),
                const SizedBox(height: 20),

                // BOTÃO GOOGLE
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fazerLoginGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.white), 
                  label: const Text("Entrar com Google", style: TextStyle(fontSize: 15)),
                ),

                const SizedBox(height: 32),

                // LINK CADASTRO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Ainda não tem conta?', style: TextStyle(color: AppColors.textSub)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                      child: const Text('Crie a sua', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)), // Terracota no link
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
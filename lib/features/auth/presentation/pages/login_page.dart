import 'package:flutter/material.dart';
import 'home_page.dart';
import 'register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o texto digitado
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Chave para validar o formulário (ex: campo vazio)
  final _formKey = GlobalKey<FormState>();

  // Variável para controlar se a senha está visível ou oculta
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    // Importante: Limpar os controladores para não vazar memória
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _fazerLogin() async {
    if (_formKey.currentState!.validate()) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrando ...')),
      );

      try {
        // 1. Tentar fazer login no Firebase
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        // 2. Sucesso! Ir para a Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );

      } on FirebaseAuthException catch (e) {
        // 3. Tratamento de Erros
        String mensagemErro = 'Erro ao fazer login. Verifique os dados.';
        
        // Nota: Por segurança, o Firebase às vezes retorna erros genéricos,
        // mas podemos tentar tratar alguns códigos.
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          mensagemErro = 'E-mail ou senha incorretos.';
        } else if (e.code == 'invalid-email') {
           mensagemErro = 'Formato de e-mail inválido.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagemErro),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                // 1. Logo ou Ícone da Academia
                const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                
                // 2. Título de Boas-vindas
                Text(
                  'Bem-vindo de volta!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acesse sua conta para treinar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // 3. Campo de E-mail
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Digite um e-mail válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. Campo de Senha
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // Oculta o texto
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite sua senha';
                    }
                    if (value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                
                // 5. Botão "Esqueci a senha" (Opcional)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Ação de recuperar senha
                    },
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Botão de Login Principal
                FilledButton(
                  onPressed: _fazerLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'ENTRAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Link para Cadastro
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
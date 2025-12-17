import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- IMPORTANTE

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _dataNascimento; // <--- Variável para guardar a data
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fazerCadastro() async {
    // Validação extra para a data
    if (_dataNascimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe sua data de nascimento.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criando a sua conta...')),
      );

      try {
        // 1. Criar Auth (Login/Senha)
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;

        // 2. Atualizar Nome no Auth
        await user?.updateDisplayName(_nameController.text.trim());

        // 3. SALVAR NO FIRESTORE (A Mágica acontece aqui)
        // Isso cria o perfil inicial para que a tela de Perfil não fique vazia
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'birthDate': Timestamp.fromDate(_dataNascimento!), // Salva a data
            'role': 'aluno', // Conforme documento técnico
            'createdAt': FieldValue.serverTimestamp(),
            // Campos opcionais começam zerados ou vazios
            'weight': 0.0,
            'objectives': 'Definir objetivo',
          });
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Pode voltar para o Login ou ir direto para Home, depende do seu fluxo.
        Navigator.pop(context); 

      } on FirebaseAuthException catch (e) {
        String mensagemErro = 'Ocorreu um erro ao registar.';
        if (e.code == 'weak-password') {
          mensagemErro = 'A senha é muito fraca.';
        } else if (e.code == 'email-already-in-use') {
          mensagemErro = 'Este e-mail já está em uso.';
        } else if (e.code == 'invalid-email') {
          mensagemErro = 'O e-mail é inválido.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crie sua conta"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                
                // Campo Nome
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Digite seu nome' : null,
                ),
                const SizedBox(height: 16),

                // --- NOVO CAMPO: DATA DE NASCIMENTO ---
                InkWell(
                  onTap: () async {
                    final dataEscolhida = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (dataEscolhida != null) {
                      setState(() {
                        _dataNascimento = dataEscolhida;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Nascimento',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dataNascimento == null
                          ? 'Toque para selecionar'
                          : '${_dataNascimento!.day}/${_dataNascimento!.month}/${_dataNascimento!.year}',
                      style: TextStyle(
                        color: _dataNascimento == null ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Campo Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Senha
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),

                // Campo Confirmar Senha
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isPasswordVisible,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botão Cadastrar
                FilledButton(
                  onPressed: _fazerCadastro,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('CADASTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
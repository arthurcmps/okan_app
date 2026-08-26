import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import 'verify_email_page.dart';
import '../../data/models/user_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = UserRoles.aluno;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();

      // 1. Cria a conta no Firebase Auth.
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: _passwordController.text.trim(),
          );

      final user = userCredential.user!;

      final uid = user.uid;

      // 2. Cria o documento canônico User v2.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'schemaVersion': UserModel.currentSchemaVersion,
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': normalizedEmail,
        'role': _selectedRole,
        'photoUrl': null,
        'academyId': null,
        'professorId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        /*
       * Compatibilidade temporária:
       * os campos abaixo permanecem na raiz
       * enquanto fitness ainda não estiver
       * totalmente ligado ao subdocumento v2.
       */
        if (_selectedRole == UserRoles.aluno) ...{
          'peso': '--',
          'altura': '--',
          'objetivo': 'Definir',
          'freq_semanal': '3x',
        },
      });

      await user.updateDisplayName(_nameController.text.trim());

      // 3. Envia verificação de e-mail.
      await user.sendEmailVerification();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const VerifyEmailPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao cadastrar.";

      if (e.code == 'weak-password') {
        msg = "Senha muito fraca (min 6 caracteres).";
      } else if (e.code == 'email-already-in-use') {
        msg = "Este e-mail já está em uso.";
      } else if (e.code == 'invalid-email') {
        msg = "E-mail inválido.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Criar Conta"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Junte-se ao Okan",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Escolha seu perfil e comece agora.",
                style: TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // SELETOR DE PERFIL
              Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      "Aluno",
                      UserRoles.aluno,
                      Icons.fitness_center,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Valor alterado de "personal" para "professor" para o painel web reconhecer
                  Expanded(
                    child: _buildRoleCard(
                      "Personal",
                      UserRoles.professor,
                      Icons.assignment_ind,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CAMPOS
              _buildTextField(
                controller: _nameController,
                label: "Nome Completo",
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: "E-mail",
                icon: Icons.email,
                isEmail: true,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: "Senha",
                icon: Icons.lock,
                isPassword: true,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _confirmPasswordController,
                label: "Confirmar Senha",
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (val) {
                  if (val != _passwordController.text)
                    return "As senhas não coincidem.";
                  return null;
                },
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black),
                      )
                    : const Text(
                        "CADASTRAR",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator:
          validator ??
          (v) {
            if (v == null || v.isEmpty) return "Obrigatório";
            if (isEmail && !v.contains('@')) return "E-mail inválido";
            if (isPassword && v.length < 6) return "Mínimo 6 caracteres";
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: AppColors.secondary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white30,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.secondary),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  Widget _buildRoleCard(String title, String value, IconData icon) {
    final isSelected = _selectedRole == value;
    final color = isSelected ? AppColors.secondary : Colors.white24;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.secondary : Colors.white60,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

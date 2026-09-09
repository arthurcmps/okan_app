import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import 'verify_email_page.dart';
import '../../data/models/user_model.dart';
import '../widgets/auth_ui.dart';

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _feedbackMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();
      final memberType = _selectedRole == UserRoles.professor
          ? UserMemberTypes.professor
          : UserMemberTypes.aluno;

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
        'memberType': memberType,
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
        setState(() => _feedbackMessage = msg);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _feedbackMessage =
              'Não foi possível concluir o cadastro. Tente novamente.',
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
      body: AuthPageFrame(
        child: AutofillGroup(
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
              _buildRoleSelector(context),
              const SizedBox(height: 24),

              // CAMPOS
              _buildTextField(
                fieldKey: const Key('register-name-field'),
                controller: _nameController,
                label: "Nome Completo",
                icon: Icons.person,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),

              _buildTextField(
                fieldKey: const Key('register-email-field'),
                controller: _emailController,
                label: "E-mail",
                icon: Icons.email,
                isEmail: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),

              AuthPasswordField(
                fieldKey: const Key('register-password-field'),
                toggleKey: const Key('register-password-toggle'),
                controller: _passwordController,
                label: "Senha",
                passwordVisible: _isPasswordVisible,
                onToggleVisibility: () => setState(
                  () => _isPasswordVisible = !_isPasswordVisible,
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: _passwordValidator,
              ),
              const SizedBox(height: 16),

              AuthPasswordField(
                fieldKey: const Key('register-confirm-password-field'),
                toggleKey: const Key('register-confirm-password-toggle'),
                controller: _confirmPasswordController,
                label: "Confirmar Senha",
                passwordVisible: _isConfirmPasswordVisible,
                onToggleVisibility: () => setState(
                  () => _isConfirmPasswordVisible =
                      !_isConfirmPasswordVisible,
                ),
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) {
                  if (!_isLoading) _register();
                },
                validator: (val) {
                  final passwordError = _passwordValidator(val);
                  if (passwordError != null) return passwordError;
                  if (val != _passwordController.text) {
                    return "As senhas não coincidem.";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              AuthFeedbackBanner(message: _feedbackMessage),
              if (_feedbackMessage != null) const SizedBox(height: 16),

              FilledButton(
                key: const Key('register-submit-button'),
                onPressed: _isLoading ? null : _register,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
      ),
    );
  }

  Widget _buildTextField({
    Key? fieldKey,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isEmail = false,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: !isEmail,
      style: const TextStyle(color: AppColors.textMain),
      validator:
          validator ??
          (v) {
            if (v == null || v.isEmpty) return "Obrigatório";
            if (isEmail && !v.contains('@')) return "E-mail inválido";
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.secondary),
      ),
    );
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Obrigatório';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Widget _buildRoleSelector(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 360 || textScale > 1.3;
        final aluno = _buildRoleCard(
          'Aluno',
          UserRoles.aluno,
          Icons.fitness_center,
        );
        final professor = _buildRoleCard(
          'Personal',
          UserRoles.professor,
          Icons.assignment_ind,
        );

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [aluno, const SizedBox(height: 12), professor],
          );
        }

        return Row(
          children: [
            Expanded(child: aluno),
            const SizedBox(width: 16),
            Expanded(child: professor),
          ],
        );
      },
    );
  }

  Widget _buildRoleCard(String title, String value, IconData icon) {
    final isSelected = _selectedRole == value;
    final color = isSelected
        ? AppColors.secondary
        : AppColors.textSub.withOpacity(0.45);

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Perfil $title',
      child: Material(
        color: isSelected
            ? AppColors.secondary.withOpacity(0.1)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color, width: isSelected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('register-role-$value'),
          onTap: () => setState(() => _selectedRole = value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textSub,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.textMain
                        : AppColors.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'register_page.dart';
import '../widgets/auth_ui.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialFeedbackMessage});

  final String? initialFeedbackMessage;

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
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _feedbackMessage = widget.initialFeedbackMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    final erro = await _authService.loginUsuario(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (erro == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        setState(
          () => _feedbackMessage = erro == 'E-mail ou senha incorretos.'
              ? erro
              : 'Não foi possível entrar agora. Tente novamente.',
        );
      }
    }
  }

  Future<void> _fazerLoginGoogle() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });
    final erro = await _authService.entrarComGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (erro == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        if (!erro.toLowerCase().contains('cancelado')) {
          setState(
            () => _feedbackMessage =
                'Não foi possível entrar com Google. Tente novamente.',
          );
        }
      }
    }
  }

  // --- NOVA FUNÇÃO: RECUPERAR SENHA ---
  Future<void> _recuperarSenha() async {
    // Aproveita o email que a pessoa já possa ter começado a digitar
    final TextEditingController emailRecuperacaoCtrl = TextEditingController(
      text: _emailController.text,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          "Recuperar senha",
          style: TextStyle(color: AppColors.textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Digite o seu email abaixo. Enviaremos um link para redefinir a sua senha.",
              style: TextStyle(color: AppColors.textSub, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailRecuperacaoCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              style: const TextStyle(color: AppColors.textMain),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: AppColors.textSub),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final email = emailRecuperacaoCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Digite um e-mail válido."),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              try {
                // A magia do Firebase acontece aqui:
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Link enviado. Verifique sua caixa de entrada e a pasta de spam.",
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } on FirebaseAuthException {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Não foi possível enviar agora. Confira o endereço e tente novamente.",
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Enviar link",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );

    emailRecuperacaoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthPageFrame(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ÍCONE LOGO
                Image.asset(
                  'assets/images/logo_okan.png',
                  height: 104,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.fitness_center,
                      size: 80,
                      color: AppColors.primary,
                    );
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
                  style: TextStyle(
                    color: AppColors.textSub,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 36),

                // EMAIL
                TextFormField(
                  key: const Key('login-email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  style: const TextStyle(color: AppColors.textMain),
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) => (val == null || !val.contains('@'))
                      ? 'E-mail inválido'
                      : null,
                ),
                const SizedBox(height: 16),

                // SENHA
                AuthPasswordField(
                  fieldKey: const Key('login-password-field'),
                  toggleKey: const Key('login-password-toggle'),
                  controller: _passwordController,
                  label: 'Senha',
                  passwordVisible: _isPasswordVisible,
                  onToggleVisibility: () => setState(
                    () => _isPasswordVisible = !_isPasswordVisible,
                  ),
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _fazerLogin();
                  },
                  validator: (val) => (val == null || val.length < 6)
                      ? 'Senha curta'
                      : null,
                ),

                // --- NOVO: BOTÃO ESQUECI A SENHA ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recuperarSenha,
                    child: const Text(
                      "Esqueci minha senha",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                AuthFeedbackBanner(message: _feedbackMessage),
                if (_feedbackMessage != null) const SizedBox(height: 16),

                // BOTÃO ENTRAR (Neon com texto preto)
                FilledButton(
                  key: const Key('login-submit-button'),
                  onPressed: _isLoading ? null : _fazerLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'ENTRAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // DIVISOR
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white10)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OU",
                        style: TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12,
                        ),
                      ),
                    ),
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
                  icon: const Icon(
                    Icons.g_mobiledata,
                    size: 28,
                    color: AppColors.textMain,
                  ),
                  label: const Text(
                    "Entrar com Google",
                    style: TextStyle(fontSize: 15),
                  ),
                ),

                const SizedBox(height: 32),

                // LINK CADASTRO
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Ainda não tem conta?',
                      style: TextStyle(color: AppColors.textSub),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      ),
                      child: const Text(
                        'Crie a sua',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

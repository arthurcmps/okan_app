import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import 'home_page.dart';
import '../widgets/auth_ui.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
  bool _isResending = false;
  String? _feedbackMessage;
  AuthFeedbackKind _feedbackKind = AuthFeedbackKind.info;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    
    // Verifica logo de cara
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Envia o e-mail (caso não tenha ido no register, mas lá já enviamos)
      // FirebaseAuth.instance.currentUser?.sendEmailVerification();

      // Cria um timer para checar a cada 3 segundos se ele verificou
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    try {
      // Recarrega o usuário para ver se o status mudou.
      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;
      setState(() {
        isEmailVerified =
            FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      });
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _feedbackKind = AuthFeedbackKind.error;
        _feedbackMessage =
            'Não foi possível verificar agora. Confira sua conexão.';
      });
      return;
    }

    if (isEmailVerified) {
      timer?.cancel();
      // Se verificou, manda pra Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Future<void> enviarNovamente() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _feedbackMessage = null;
    });

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _feedbackKind = AuthFeedbackKind.success;
        _feedbackMessage =
            'E-mail reenviado. Confira também sua pasta de spam.';
      });
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _feedbackKind = AuthFeedbackKind.error;
        _feedbackMessage =
            'Não foi possível reenviar agora. Aguarde e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return isEmailVerified 
      ? const HomePage() // Se já verificou, mostra a Home (redundância)
      : Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text("Verifique seu E-mail"),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: AuthPageFrame(
            child: Semantics(
              container: true,
              label: 'Confirmação de e-mail',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 100,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "E-mail de verificação enviado!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Enviamos um link para "
                    "${FirebaseAuth.instance.currentUser?.email}.\n"
                    "Clique no link para ativar sua conta.",
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSub,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aguardando confirmação...",
                    style: TextStyle(color: AppColors.textSub),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  AuthFeedbackBanner(
                    message: _feedbackMessage,
                    kind: _feedbackKind,
                  ),
                  if (_feedbackMessage != null) const SizedBox(height: 16),

                  OutlinedButton.icon(
                    icon: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.email_outlined),
                    label: Text(
                      _isResending ? 'REENVIANDO...' : 'REENVIAR E-MAIL',
                    ),
                    onPressed: _isResending ? null : enviarNovamente,
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text(
                      "Sair e voltar ao login",
                      style: TextStyle(color: AppColors.textSub),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

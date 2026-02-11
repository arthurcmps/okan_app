import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import 'home_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
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
    // Recarrega o usuário para ver se o status mudou
    await FirebaseAuth.instance.currentUser?.reload();
    
    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

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
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail reenviado!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
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
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 100, color: AppColors.secondary),
                const SizedBox(height: 24),
                const Text(
                  "E-mail de verificação enviado!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Enviamos um link para ${FirebaseAuth.instance.currentUser?.email}.\nClique no link para ativar sua conta.",
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: AppColors.secondary),
                const SizedBox(height: 16),
                const Text("Aguardando confirmação...", style: TextStyle(color: Colors.white30)),
                const SizedBox(height: 40),
                
                TextButton.icon(
                  icon: const Icon(Icons.email, color: AppColors.primary),
                  label: const Text("Reenviar E-mail", style: TextStyle(color: AppColors.primary)),
                  onPressed: enviarNovamente,
                ),
                
                TextButton(
                  child: const Text("Cancelar / Sair", style: TextStyle(color: Colors.grey)),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                )
              ],
            ),
          ),
        );
  }
}
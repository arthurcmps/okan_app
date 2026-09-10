import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'onboarding_page.dart';

typedef AuthDestinationBuilder = Widget Function(BuildContext context);

class AuthCheck extends StatelessWidget {
  const AuthCheck({
    super.key,
    this.showOnboarding = false,
    this.authStateChanges,
    this.homeBuilder,
    this.loginBuilder,
    this.onboardingBuilder,
  });

  final bool showOnboarding;
  final Stream<User?>? authStateChanges;
  final AuthDestinationBuilder? homeBuilder;
  final AuthDestinationBuilder? loginBuilder;
  final AuthDestinationBuilder? onboardingBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // idTokenChanges também reage quando o SDK invalida ou renova a sessão.
      // Manter o listener sempre ativo evita deixar uma Home autenticada montada
      // depois que o usuário deixa de existir para o Firebase Auth.
      stream: authStateChanges ?? FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.data != null) {
          return homeBuilder?.call(context) ?? const HomePage();
        }

        if (showOnboarding) {
          return onboardingBuilder?.call(context) ?? const OnboardingPage();
        }

        return loginBuilder?.call(context) ?? const LoginPage();
      },
    );
  }
}

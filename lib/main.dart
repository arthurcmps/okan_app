import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'core/services/time_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('pt_BR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okan App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      
      // --- A MÁGICA GLOBAL AQUI ---
      // O 'builder' permite envolver todas as telas do app com um widget extra
      builder: (context, child) {
        return Scaffold(
          // O 'child' é a tela atual (Login, Home, Treino, etc)
          body: Stack(
            children: [
              child!, 
              
              // Barra do Cronômetro Flutuante
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GlobalTimerBar(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget que desenha a barra laranja
class GlobalTimerBar extends StatefulWidget {
  const GlobalTimerBar({super.key});

  @override
  State<GlobalTimerBar> createState() => _GlobalTimerBarState();
}

class _GlobalTimerBarState extends State<GlobalTimerBar> {
  @override
  void initState() {
    super.initState();
    // Ouve as mudanças do TimerService para redesenhar a barra
    TimerService.instance.addListener(_atualizar);
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_atualizar);
    super.dispose();
  }

  void _atualizar() {
    setState(() {}); // Força o rebuild quando o tempo muda
  }

  @override
  Widget build(BuildContext context) {
    // Se o timer não está ativo, não desenha nada (barra invisível)
    if (!TimerService.instance.isActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Colors.orange.shade700,
      child: Material( // Material necessário para os ícones funcionarem bem sobrepondo
        color: Colors.transparent,
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              "Descanso: ${TimerService.instance.formattedTime}",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              onPressed: () => TimerService.instance.addTime(10),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => TimerService.instance.stop(),
            ),
          ],
        ),
      ),
    );
  }
}
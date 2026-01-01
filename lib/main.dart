import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'core/services/time_service.dart';
// --- PALETA SPORT MODERN ---
class AppColors {
  static const Color background = Color(0xFFF1F5F9); // Cinza Slate Claro (Moderno)
  static const Color surface = Color(0xFFFFFFFF);    // Branco Puro
  static const Color primary = Color(0xFF2563EB);    // Azul Royal Vibrante
  static const Color secondary = Color(0xFF0EA5E9);  // Azul Céu (Degradês)
  static const Color textMain = Color(0xFF1E293B);   // Azul Noturno (Quase preto)
  static const Color textSub = Color(0xFF64748B);    // Cinza Azulado
  static const Color success = Color(0xFF10B981);    // Verde Esmeralda
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('pt_BR', null);
  runApp(const OkanApp());
}

final ThemeData sportTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.background,
  
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    surface: AppColors.surface,
  ),

  // CARDS ESTILIZADOS
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 8, // Sombra mais marcada porém difusa
    shadowColor: const Color(0xFF64748B).withOpacity(0.15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  ),

  // APPBAR LIMPA
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: AppColors.textMain),
    titleTextStyle: TextStyle(
      color: AppColors.textMain, 
      fontSize: 24, 
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
  ),

  // TEXTOS MODERNOS
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w900),
    titleMedium: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w500),
  ),

  // BOTÕES ARREDONDADOS
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: AppColors.primary.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),

  // INPUTS
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), 
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  ),
);

class OkanApp extends StatelessWidget {
  const OkanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okan App',
      debugShowCheckedModeBanner: false,
      theme: sportTheme,
      home: const LoginPage(),
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              if (child != null) child!, 
              const Positioned(bottom: 0, left: 0, right: 0, child: GlobalTimerBar()),
            ],
          ),
        );
      },
    );
  }
}

class GlobalTimerBar extends StatefulWidget {
  const GlobalTimerBar({super.key});
  @override
  State<GlobalTimerBar> createState() => _GlobalTimerBarState();
}

class _GlobalTimerBarState extends State<GlobalTimerBar> {
  @override
  void initState() {
    super.initState();
    TimerService.instance.addListener(_atualizar);
  }
  @override
  void dispose() {
    TimerService.instance.removeListener(_atualizar);
    super.dispose();
  }
  void _atualizar() { setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (!TimerService.instance.isActive) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Card escuro flutuante
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Text(TimerService.instance.formattedTime, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add, color: Colors.blueAccent), onPressed: () => TimerService.instance.addTime(10)),
            const SizedBox(width: 8),
            InkWell(onTap: () => TimerService.instance.stop(), child: const Icon(Icons.close, color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}
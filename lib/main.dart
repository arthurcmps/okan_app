import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/home_page.dart';
import 'core/services/time_service.dart';
import 'features/auth/presentation/controllers/tarefa_controller.dart';
import 'core/theme/app_colors.dart'; 
// O import já estava aqui, perfeito:
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // --- NOVO CÓDIGO DE PUSH NOTIFICATION ---
    // Inicializa o serviço, pede permissão e salva o token no Firestore
    final pushService = PushNotificationService();
    await pushService.initialize();
    pushService.setupInteractions();
    // ----------------------------------------

    await initializeDateFormatting('pt_BR', null);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TarefaController()..iniciarEscuta(),
          ),
        ],
        child: const OkanApp(),
      ),
    );

  } catch (e, stackTrace) {
    runApp(AppErrorScreen(error: e, stackTrace: stackTrace));
  }
}

// --- TEMA DO APP (CYBER-SANKOFA) ---
final ThemeData sportTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark, 
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Montserrat', 
  
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    onPrimary: Colors.black, 
    onSecondary: Colors.white, 
  ),

  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0, 
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1) 
    ),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  ),

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

  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w900),
    titleMedium: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w500),
  ),

  iconTheme: const IconThemeData(
    color: AppColors.primary, 
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black, 
      elevation: 0, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
    ),
  ),
  
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textMain, 
      side: const BorderSide(color: AppColors.textSub, width: 1), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface, 
    labelStyle: const TextStyle(color: AppColors.textSub),
    hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.5)),
    prefixIconColor: AppColors.textSub, 
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), 
      borderSide: const BorderSide(color: AppColors.primary, width: 1), 
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), 
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
  ),
  
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return AppColors.primary; 
      }
      return Colors.transparent;
    }),
    checkColor: MaterialStateProperty.all(Colors.black), 
    side: const BorderSide(color: AppColors.textSub, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
);

// --- WIDGET RAIZ ---
class OkanApp extends StatelessWidget {
  const OkanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okan App',
      debugShowCheckedModeBanner: false,
      theme: sportTheme,
      home: const AuthCheck(), 
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent, 
          body: Stack(
            children: [
              if (child != null) child!, 
              const Positioned(
                bottom: 0, left: 0, right: 0, 
                child: GlobalTimerBar() 
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- AUTH CHECK ---
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

// --- BARRA DE TIMER GLOBAL ---
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
  
  void _atualizar() { 
    if (mounted) setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    if (!TimerService.instance.isActive) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)), // Borda Neon
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primary), // Ícone Neon
              const SizedBox(width: 12),
              Text(
                TimerService.instance.formattedTime, 
                style: const TextStyle(
                  color: AppColors.textMain, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  fontFamily: 'monospace'
                )
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary), // Terracota no botão secundário
                onPressed: () => TimerService.instance.addTime(10)
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => TimerService.instance.stop(), 
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.2), 
                    shape: BoxShape.circle
                  ),
                  child: const Icon(Icons.close, color: AppColors.error, size: 20)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TELA DE ERRO ---
class AppErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const AppErrorScreen({super.key, required this.error, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bug_report_outlined, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text("ERRO NA INICIALIZAÇÃO", style: TextStyle(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: Text(error.toString(), style: const TextStyle(color: Colors.orange)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Necessário para o AuthCheck
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';

// Configurações do Firebase
// Se der erro aqui, certifique-se de ter rodado "flutterfire configure"
import 'firebase_options.dart';

// Importações das suas Features
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/home_page.dart'; // Importante para o redirecionamento
// import 'features/auth/presentation/pages/auth_check.dart'; // Removi pois criei a classe abaixo
import 'core/services/time_service.dart';

// Importando a nova feature de Tarefas
import 'features/auth/presentation/pages/tarefas_page.dart';
import 'features/auth/presentation/controllers/tarefa_controller.dart';

// --- PALETA SPORT MODERN ---
class AppColors {
  static const Color background = Color(0xFFF1F5F9); 
  static const Color surface = Color(0xFFFFFFFF);    
  static const Color primary = Color(0xFF2563EB);    
  static const Color secondary = Color(0xFF0EA5E9);  
  static const Color textMain = Color(0xFF1E293B);   
  static const Color textSub = Color(0xFF64748B);    
  static const Color success = Color(0xFF10B981);    
  static const Color error = Color(0xFFEF4444);      
}

// --- PONTO DE ENTRADA ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    // 1. Inicia Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Configura Datas
    await initializeDateFormatting('pt_BR', null);

    // 3. Roda o App injetando os Providers (Controladores)
    runApp(
      MultiProvider(
        providers: [
          // Injetando o Controller de Tarefas
          ChangeNotifierProvider(
            create: (_) => TarefaController()..iniciarEscuta(),
          ),
        ],
        child: const OkanApp(),
      ),
    );

  } catch (e, stackTrace) {
    // 4. Tela de Erro de Inicialização
    runApp(AppErrorScreen(error: e, stackTrace: stackTrace));
  }
}

// --- TEMA DO APP ---
final ThemeData sportTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.background,
  
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    surface: AppColors.surface,
    error: AppColors.error,
  ),

  // CARDS
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 8,
    shadowColor: const Color(0xFF64748B).withOpacity(0.15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  ),

  // APPBAR
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

  // TEXTOS
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w900),
    titleMedium: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w500),
  ),

  // BOTÕES
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), 
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), 
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
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
      
      // Define a AuthCheck como a tela inicial
      home: const AuthCheck(), 

      // Builder global para o Timer flutuante
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent, 
          // Stack permite que o timer fique sobre qualquer tela
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

// --- CLASSE AUTH CHECK (O GUARDA DE TRÂNSITO) ---
// Adicionei aqui para evitar erros de importação
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Verificando...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // 2. Tem Usuário? Vai pra Home
        if (snapshot.hasData) {
          return const HomePage();
        }
        // 3. Não tem? Vai pro Login
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
    // Escuta mudanças no serviço de tempo
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
    // Se o timer não estiver ativo, não mostra nada
    if (!TimerService.instance.isActive) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.amberAccent),
              const SizedBox(width: 12),
              Text(
                TimerService.instance.formattedTime, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  fontFamily: 'monospace'
                )
              ),
              const Spacer(),
              // BOTÃO ADICIONAR TEMPO
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent), 
                onPressed: () => TimerService.instance.addTime(10)
              ),
              const SizedBox(width: 4),
              // BOTÃO FECHAR
              InkWell(
                onTap: () => TimerService.instance.stop(), 
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.redAccent, size: 20)
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
        backgroundColor: Colors.blue.shade900,
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
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: Text(error.toString(), style: const TextStyle(color: Colors.amberAccent)),
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
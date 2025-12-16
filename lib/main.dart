import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Garante que o motor do Flutter esteja inicializado
  WidgetsFlutterBinding.ensureInitialized();
  // 2. Inicializa o Firebase com as opções padrão da plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp ({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Okan App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text("Firebase Inicializado com Sucesso!")),
      ),
    );
  }
}
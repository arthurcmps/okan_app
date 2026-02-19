import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Pedir permissão ao usuário (Obrigatório para iOS e Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permissão de Push concedida!');
      
      // --- NOVO: Força notificações a tocarem som e aparecerem no Foreground (App aberto) ---
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, // Mostra o banner no topo
        badge: true, // Atualiza a contagem no ícone do app
        sound: true, // Toca o som e vibra
      );

      // 2. Obter o Token único deste aparelho
      String? token = await _fcm.getToken();
      
      // 3. Salvar o Token no banco de dados para a Cloud Function encontrar
      if (token != null) {
        await _saveTokenToDatabase(token);
        debugPrint('FCM Token gerado: $token');
      }

      // 4. Atualizar o banco caso o token do aparelho mude (ex: app reinstalado)
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    } else {
      debugPrint('Usuário negou a permissão de Push.');
    }
  }

  // --- Lógica para salvar o Token na coleção do Usuário ---
  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Usamos arrayUnion para não apagar os tokens de outros aparelhos do usuário (se ele usar tablet + celular, por exemplo)
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }).catchError((e) {
      debugPrint('Erro ao salvar FCM Token: $e');
    });
  }
  
  // --- Configura o que acontece quando o usuário CLICA na notificação ---
  void setupInteractions() {
    // 1. Quando o app está aberto na tela (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Recebi notificação no foreground: ${message.notification?.title}");
      // Nota: No iOS o banner já vai aparecer. 
      // No Android, se quiser um banner customizado no foreground, precisaria do pacote flutter_local_notifications.
    });

    // 2. Quando o app está em segundo plano e o usuário clica no banner
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Usuário clicou na notificação que estava em background!");
      _handleNotificationClick(message);
    });

    // 3. Quando o app estava totalmente fechado (morto) e foi aberto pelo clique na notificação
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("App foi aberto a partir de uma notificação!");
        _handleNotificationClick(message);
      }
    });
  }

  // Helper para rotear o usuário para a tela certa
  void _handleNotificationClick(RemoteMessage message) {
    final type = message.data['type'];
    final actionId = message.data['actionId'];

    debugPrint('Redirecionando pelo tipo: $type, ID: $actionId');
    // Aqui no futuro você pode adicionar sua lógica de navegação usando um GlobalKey<NavigatorState>
    // Ex: if (type == 'message') Navigator.pushNamed('/chat', arguments: actionId);
  }
}
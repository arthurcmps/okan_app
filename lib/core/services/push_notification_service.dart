import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; 
import '../../features/auth/presentation/pages/notifications_page.dart'; 

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Guardamos a chave mestra da navegação aqui
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize() async {
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
      
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, 
        badge: true, 
        sound: true, 
      );

      String? token = await _fcm.getToken();
      
      if (token != null) {
        await _saveTokenToDatabase(token);
        debugPrint('FCM Token gerado: $token');
      }

      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    } else {
      debugPrint('Usuário negou a permissão de Push.');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }).catchError((e) {
      debugPrint('Erro ao salvar FCM Token: $e');
    });
  }
  
  // --- AGORA RECEBE O NAVIGATOR KEY COMO PARÂMETRO ---
  void setupInteractions(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Recebi notificação no foreground: ${message.notification?.title}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Usuário clicou na notificação que estava em background!");
      _handleNotificationClick(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("App foi aberto a partir de uma notificação!");
        // Pequeno delay para garantir que o MaterialApp já foi construído antes de empurrar a nova rota
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationClick(message);
        });
      }
    });
  }

  void _handleNotificationClick(RemoteMessage message) {
    final type = message.data['type'];
    final actionId = message.data['actionId'];

    debugPrint('Redirecionando pelo tipo: $type, ID: $actionId');

    // Verifica se temos a chave e se o navegador já está pronto
    if (_navigatorKey != null && _navigatorKey!.currentState != null) {
      
      // Independentemente se é um convite (invite), treino atualizado (workout_update), ou mensagem (message)
      // A NotificationsPage é a "Central de Comando" onde ele resolve tudo.
      if (type == 'invite' || type == 'workout_update' || type == 'message' || type == 'workout') {
        _navigatorKey!.currentState!.push(
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
      }
    }
  }
}
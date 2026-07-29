import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/auth/presentation/pages/notifications_page.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Instância do plugin de notificações locais declarada aqui para evitar erros
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

      // Garante que tentaremos pegar e salvar o token no banco
      await salvarTokenAtual();

      // Fica ouvindo caso o token do dispositivo mude
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    } else {
      debugPrint('Usuário negou a permissão de Push.');
    }
  }

  // Função isolada para poder ser chamada de fora quando o usuário logar
  Future<void> salvarTokenAtual() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
        debugPrint('FCM Token gerado e salvo: $token');
      }
    } catch (e) {
      debugPrint('Erro ao obter token do FCM: $e');
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
  
  void setupInteractions(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // 1. ABERTO EM PRIMEIRO PLANO (Foreground) - Mostra o banner Android
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Recebi notificação no foreground: ${message.notification?.title}");
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notificações Importantes',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    }); // <-- AQUI ESTAVA FALTANDO FECHAR O ");"

    // 2. CLIQUE EM SEGUNDO PLANO (Background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Usuário clicou na notificação que estava em background!");
      _handleNotificationClick(message);
    });

    // 3. CLIQUE COM APP FECHADO (Terminated)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("App foi aberto a partir de uma notificação!");
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

    if (_navigatorKey != null && _navigatorKey!.currentState != null) {
      if (type == 'invite' || type == 'workout_update' || type == 'message' || type == 'workout') {
        _navigatorKey!.currentState!.push(
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
      }
    }
  }
}
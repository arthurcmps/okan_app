import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Pedir permissão (Essencial para iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permissão de Push concedida!');
      
      // 2. Obter o Token do dispositivo
      String? token = await _fcm.getToken();
      
      // 3. Salvar o Token no perfil do usuário
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // 4. Escutar atualizações de token (caso mude)
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Salvamos numa subcoleção ou array para suportar múltiplos dispositivos
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]), // Adiciona sem duplicar
    });
  }
  
  // Opcional: Configurar o que acontece quando clica na notificação com o app aberto
  void setupInteractions() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Notificação recebida com o app ABERTO (Foreground)
      // Você pode mostrar um SnackBar ou atualizar o contador da Home
      debugPrint("Recebi notificação no foreground: ${message.notification?.title}");
    });
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class RunningNotificationPermissionService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> ensurePermission() async {
    if (!_isAndroid) return true;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      throw StateError(
        'O serviço de notificações do Android não está disponível.',
      );
    }

    final enabled = await android.areNotificationsEnabled();

    if (enabled == true) return true;

    await android.requestNotificationsPermission();

    // Consulta novamente o estado real depois da resposta do usuário.
    return await android.areNotificationsEnabled() == true;
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}

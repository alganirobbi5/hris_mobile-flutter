import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static bool get initialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      await Firebase.initializeApp();
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});

      messaging.onRegistered.listen((String token) {
        sendTokenToServer(token);
      });
      await messaging.register();

      _initialized = true;
    } catch (e) {
      debugPrint('Firebase tidak tersedia: $e');
    }
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    debugPrint('Push background: ${message.notification?.title}');
  }

  static Future<void> syncToken() async {
    if (!_initialized) return;
    await FirebaseMessaging.instance.register();
  }

  static Future<void> sendTokenToServer(String token) async {
    final String? apiToken = await AppSession.resolveToken();
    if (apiToken == null || apiToken.isEmpty) return;

    try {
      await http
          .post(
            ApiConfig.uri('fcm_token.php'),
            headers: ApiConfig.authHeaders(apiToken),
            body: {'fcm_token': token},
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Gagal menyimpan FCM token ke server: $e');
    }
  }

  static Future<void> clearToken() async {
    if (!_initialized) return;
    final String? apiToken = await AppSession.resolveToken();
    if (apiToken == null || apiToken.isEmpty) return;
    try {
      await http
          .delete(
            ApiConfig.uri('fcm_token.php'),
            headers: ApiConfig.authHeaders(apiToken),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Gagal menghapus FCM token: $e');
    }
  }
}

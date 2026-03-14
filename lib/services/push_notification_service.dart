import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

/// WhatsApp-style push: status bar notifications when app is closed/background.
/// Requires: Firebase project, google-services.json, and run `dart run flutterfire_cli:flutterfire configure`.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Notification is shown by FCM when app is in background/terminated.
}

class PushNotificationService {
  static final _client = Supabase.instance.client;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isAndroid) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _initialized = true;
    } catch (e) {
      print('❌ PushNotificationService init: $e');
    }
  }

  /// Call after user or field officer is known (e.g. on dashboard load).
  static Future<void> registerToken({
    String? userId,
    String? fieldOfficerId,
  }) async {
    if (!_initialized) await init();
    if (userId == null && fieldOfficerId == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _client.from('fcm_tokens').upsert(
        {
          'token': token,
          'user_id': userId,
          'field_officer_id': fieldOfficerId,
          'platform': 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      print('❌ PushNotificationService registerToken: $e');
    }
  }

  /// Call from main.dart to set up foreground and tap handlers.
  static void setForegroundAndTapHandlers({
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onMessageOpenedApp,
  }) {
    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpenedApp?.call(message);
    });
  }
}

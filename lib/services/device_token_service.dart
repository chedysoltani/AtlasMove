import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';

/// Enregistre le token FCM du device auprès du backend.
/// Spec : POST /users/devices  { device_token, platform }
class DeviceTokenService {
  static final DeviceTokenService _instance = DeviceTokenService._internal();
  factory DeviceTokenService() => _instance;
  DeviceTokenService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// À appeler après un login réussi.
  Future<void> registerDevice() async {
    try {
      // Demander la permission (iOS obligatoire, Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ DeviceTokenService: permission refusée');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ DeviceTokenService: token FCM null');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await HttpClient.post('/users/devices', body: {
        'device_token': token,
        'platform': platform,
      });

      if (response.isSuccess) {
        debugPrint('✅ DeviceTokenService: token enregistré (platform=$platform)');
      } else {
        debugPrint('❌ DeviceTokenService: échec ${response.statusCode}');
      }

      // Réécouter les rafraîchissements de token
      _messaging.onTokenRefresh.listen((newToken) async {
        await HttpClient.post('/users/devices', body: {
          'device_token': newToken,
          'platform': platform,
        });
        debugPrint('🔄 DeviceTokenService: token FCM rafraîchi');
      });
    } catch (e) {
      debugPrint('💥 DeviceTokenService: $e');
    }
  }
}

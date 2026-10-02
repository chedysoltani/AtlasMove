import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/permission_gate.dart';
import '../providers/locale_provider.dart';

/// Enregistre le token FCM du device auprès du backend.
///
/// Contrat backend : `POST /users/devices`
/// `{ device_token, platform, device_id, app_version, locale, voip_token? }`.
/// Les lignes sont upsertées par (utilisateur, `device_id`) : un token FCM qui
/// tourne remplace l'ancienne ligne au lieu d'en créer une morte.
/// À la déconnexion, le token est supprimé via `pushToken` dans
/// `POST /m/auth/logout` (voir AuthSession.logout) — il n'existe pas de route DELETE.
class DeviceTokenService {
  static final DeviceTokenService _instance = DeviceTokenService._internal();
  factory DeviceTokenService() => _instance;
  DeviceTokenService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _refreshSub;

  /// À appeler après un login réussi.
  Future<void> registerDevice() async {
    try {
      // Demander la permission (iOS obligatoire, Android 13+)
      // Via la file : une seule demande de permission système à la fois
      final settings = await PermissionGate.run(
        () => _messaging.requestPermission(alert: true, badge: true, sound: true),
        timeout: const Duration(seconds: 120),
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

      final ok = await _post(token);
      debugPrint(ok
          ? '✅ DeviceTokenService: token enregistré'
          : '❌ DeviceTokenService: enregistrement échoué');

      // Un seul abonnement aux rotations de token, même si registerDevice est
      // rappelé à chaque login. Le device_id étant stable, la ligne serveur est
      // remplacée (pas dupliquée).
      await _refreshSub?.cancel();
      _refreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        await _post(newToken);
        debugPrint('🔄 DeviceTokenService: token FCM rafraîchi');
      });
    } catch (e) {
      debugPrint('💥 DeviceTokenService: ${e.runtimeType}');
    }
  }

  Future<bool> _post(String deviceToken) async {
    try {
      final response = await HttpClient.post('/users/devices', body: {
        'device_token': deviceToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_id': await TokenStorage.getOrCreateDeviceId(),
        'app_version': HttpClient.appVersion,
        // Langue CHOISIE dans l'app (pas celle du téléphone) : sert à localiser les push
        'locale': (await LocaleProvider.getSavedLocale()).languageCode,
      });
      return response.isSuccess;
    } catch (e) {
      debugPrint('DeviceTokenService._post: ${e.runtimeType}');
      return false;
    }
  }

  /// Renvoie la ligne device au backend (ex. après un changement de langue).
  Future<void> syncRegistration() async {
    if (!await TokenStorage.hasSession()) return;
    final token = await currentToken();
    if (token != null && token.isNotEmpty) await _post(token);
  }

  /// Token FCM courant (à envoyer en `pushToken` dans `POST /m/auth/logout`).
  Future<String?> currentToken() async {
    try {
      return await _messaging.getToken().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  /// Après le logout côté serveur : stoppe l'écoute et invalide le token FCM
  /// local. Même si l'appel serveur a échoué (hors-ligne), l'appareil ne
  /// reçoit plus aucun push du compte déconnecté.
  Future<void> invalidateLocalToken() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}

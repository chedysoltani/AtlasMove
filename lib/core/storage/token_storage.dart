import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des tokens — EncryptedSharedPreferences (Android) / Keychain (iOS)
class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _tokenSavedAtKey = 'token_saved_at';
  // Posé à 'true' lors d'un logout explicite — bloque l'auto-login au redémarrage.
  static const _explicitLogoutKey = 'explicit_logout';
  // Identifiant stable de l'appareil — généré une seule fois, jamais effacé au logout.
  static const _deviceIdKey = 'device_id';

  // « Se souvenir de moi » + identifiant pré-rempli (jamais le mot de passe).
  static const _rememberMeKey = 'remember_me';
  static const _savedIdentifierKey = 'saved_identifier';

  // Repli quand le token n'est pas un JWT lisible : TTL présumé 15 min, refresh à 13 min.
  static const int _refreshBeforeExpirySeconds = 780;

  // resetOnError : si le Keystore Android ne peut plus déchiffrer le fichier
  // (restauration d'un backup, clé invalidée), les données sont de toute façon
  // irrécupérables — on repart d'un stockage vide au lieu de planter à chaque lecture.
  // first_unlock : le token reste lisible quand l'app est relancée en arrière-plan
  // (push, foreground service) téléphone verrouillé après le premier déverrouillage.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Lecture tolérante : une erreur de plateforme (Keystore/Keychain) ne doit
  /// jamais faire planter le démarrage ni être prise pour une session invalide.
  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('⚠️ TokenStorage: lecture de "$key" impossible (${e.runtimeType})');
      return null;
    }
  }

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  static Future<String?> getAccessToken() => _read(_accessTokenKey);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  static Future<String?> getRefreshToken() => _read(_refreshTokenKey);

  static Future<void> saveUserId(String userId) =>
      _storage.write(key: _userIdKey, value: userId);

  static Future<String?> getUserId() => _read(_userIdKey);

  static Future<void> saveUserRole(String role) =>
      _storage.write(key: _userRoleKey, value: role);

  static Future<String?> getUserRole() => _read(_userRoleKey);

  static Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
    String? role,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(
          key: _tokenSavedAtKey,
          value: DateTime.now().millisecondsSinceEpoch.toString()),
      // Nouvelle connexion réussie → lever le flag de logout explicite
      _storage.delete(key: _explicitLogoutKey),
      if (refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      if (userId != null) _storage.write(key: _userIdKey, value: userId),
      if (role != null) _storage.write(key: _userRoleKey, value: role),
    ]);
  }

  static Future<bool> isAccessTokenExpiringSoon() async {
    final savedAtStr = await _read(_tokenSavedAtKey);
    if (savedAtStr == null) return false;
    final savedAt = int.tryParse(savedAtStr) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    return age >= _refreshBeforeExpirySeconds * 1000;
  }

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userRoleKey),
      _storage.delete(key: _tokenSavedAtKey),
      // Marquer que l'utilisateur a explicitement demandé la déconnexion
      _storage.write(key: _explicitLogoutKey, value: 'true'),
    ]);
  }

  /// Vérifie si l'utilisateur s'est déconnecté explicitement (bloque l'auto-login)
  static Future<bool> wasExplicitlyLoggedOut() async {
    final val = await _read(_explicitLogoutKey);
    return val == 'true';
  }

  /// Effacer le flag logout lors d'une nouvelle connexion réussie
  static Future<void> clearLogoutFlag() async {
    await _storage.delete(key: _explicitLogoutKey);
  }

  /// Retourne le deviceId stable de cet appareil.
  /// Généré une fois via Random.secure() au format UUID v4, persisté en stockage sécurisé.
  /// Jamais effacé par clearTokens() — représente l'appareil, pas la session utilisateur.
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Une session (même expirée) est-elle stockée ? Un refresh token suffit :
  /// l'access token sera renouvelé silencieusement.
  static Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    if (refresh != null && refresh.isNotEmpty) return true;
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }

  // ── Se souvenir de moi ────────────────────────────────────────────────────

  /// Absent (installations antérieures à la fonction) = true : on ne déconnecte
  /// pas les utilisateurs existants à la mise à jour.
  static Future<bool> getRememberMe() async =>
      (await _read(_rememberMeKey)) != 'false';

  static Future<void> saveRememberMe(bool value) =>
      _storage.write(key: _rememberMeKey, value: value.toString());

  static Future<String?> getSavedIdentifier() => _read(_savedIdentifierKey);

  static Future<void> saveSavedIdentifier(String identifier) =>
      _storage.write(key: _savedIdentifierKey, value: identifier);

  static Future<void> clearSavedIdentifier() =>
      _storage.delete(key: _savedIdentifierKey);
}

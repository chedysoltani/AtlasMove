import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des tokens — EncryptedSharedPreferences (Android) / Keychain (iOS)
class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _tokenSavedAtKey = 'token_saved_at';

  // Access token TTL 15 min — rafraîchir à 13 min pour laisser une marge
  static const int _refreshBeforeExpirySeconds = 780;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  static Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    debugPrint('🔍 TokenStorage: token=${token != null ? "[présent]" : "null"}');
    return token;
  }

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> saveUserId(String userId) =>
      _storage.write(key: _userIdKey, value: userId);

  static Future<String?> getUserId() => _storage.read(key: _userIdKey);

  static Future<void> saveUserRole(String role) =>
      _storage.write(key: _userRoleKey, value: role);

  static Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  static Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
    String? role,
  }) async {
    debugPrint('💾 TokenStorage: Sauvegarde sécurisée des tokens...');
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(
          key: _tokenSavedAtKey,
          value: DateTime.now().millisecondsSinceEpoch.toString()),
      if (refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      if (userId != null) _storage.write(key: _userIdKey, value: userId),
      if (role != null) _storage.write(key: _userRoleKey, value: role),
    ]);
    debugPrint('✅ TokenStorage: Tokens sauvegardés (stockage sécurisé)');
  }

  static Future<bool> isAccessTokenExpiringSoon() async {
    final savedAtStr = await _storage.read(key: _tokenSavedAtKey);
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
    ]);
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String?>> getAllTokens() async => {
        'access_token': await _storage.read(key: _accessTokenKey),
        'refresh_token': await _storage.read(key: _refreshTokenKey),
        'user_id': await _storage.read(key: _userIdKey),
      };
}

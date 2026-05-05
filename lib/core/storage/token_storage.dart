import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer le stockage sécurisé des tokens d'authentification
class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  /// Sauvegarder le token d'accès
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  /// Récupérer le token d'accès
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    debugPrint('🔍 TokenStorage: Récupération du token: $token');
    return token;
  }

  /// Sauvegarder le token de rafraîchissement
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  /// Récupérer le token de rafraîchissement
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Sauvegarder l'ID de l'utilisateur
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  /// Récupérer l'ID de l'utilisateur
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Sauvegarder tous les tokens d'authentification
  static Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    debugPrint('💾 TokenStorage: Sauvegarde des tokens...');
    debugPrint('  - Access Token: $accessToken');
    debugPrint('  - User ID: $userId');
    
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_accessTokenKey, accessToken),
      if (refreshToken != null) prefs.setString(_refreshTokenKey, refreshToken),
      if (userId != null) prefs.setString(_userIdKey, userId),
    ]);
    
    debugPrint('✅ TokenStorage: Tokens sauvegardés avec succès');
  }

  /// Supprimer tous les tokens (déconnexion)
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_userIdKey),
    ]);
  }

  /// Vérifier si l'utilisateur est authentifié
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Récupérer tous les tokens (pour le debug)
  static Future<Map<String, String?>> getAllTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access_token': prefs.getString(_accessTokenKey),
      'refresh_token': prefs.getString(_refreshTokenKey),
      'user_id': prefs.getString(_userIdKey),
    };
  }
}

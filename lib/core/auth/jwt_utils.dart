import 'dart:convert';

/// Lecture (sans vérification de signature) des claims d'un JWT.
/// Sert uniquement à connaître l'expiration côté client — le serveur reste juge.
class JwtUtils {
  JwtUtils._();

  static Map<String, dynamic>? claims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Date d'expiration (UTC) du claim `exp`, ou null si absente / illisible.
  static DateTime? expiry(String token) {
    final exp = claims(token)?['exp'];
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
    return null;
  }

  /// Rôle éventuellement présent dans le token (`role`, `roles[0]`, `user.role`).
  static String? role(String token) {
    final c = claims(token);
    if (c == null) return null;
    final r = c['role'] ??
        (c['roles'] is List && (c['roles'] as List).isNotEmpty
            ? (c['roles'] as List).first
            : null) ??
        (c['user'] is Map ? (c['user'] as Map)['role'] : null);
    return r?.toString();
  }
}

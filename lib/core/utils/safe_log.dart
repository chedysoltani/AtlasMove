import 'package:flutter/foundation.dart';

/// Logs qui ne fuient jamais de secrets.
///
/// `debugPrint` écrit aussi en release (logcat / console iOS) : tout ce qui
/// contient un mot de passe, un token ou un OTP passe par [redact] et n'est
/// émis qu'en debug.
class SafeLog {
  SafeLog._();

  static const String _keys = 'password|newPassword|confirm_password|confirmPassword|'
      'otpCode|otp|accessToken|access_token|refreshToken|refresh_token|token|'
      'sessionToken|session_token|authorization|x-session-token';

  // clé (avec ou sans guillemets) + séparateur + valeur (chaîne JSON, "Bearer xxx" ou mot nu)
  static final RegExp _sensitive = RegExp(
    '("?(?:$_keys)"?\\s*[:=]\\s*)'
    '("(?:[^"\\\\]|\\\\.)*"|Bearer\\s+[^\\s,}&]+|[^\\s,}&]+)',
    caseSensitive: false,
  );

  /// Masque les valeurs sensibles d'un JSON / d'une chaîne de headers.
  static String redact(String input) =>
      input.replaceAllMapped(_sensitive, (m) => '${m[1]}"***"');

  /// Message sans donnée sensible — debug uniquement.
  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Corps de requête / réponse : masqué, et debug uniquement.
  static void body(String label, String raw) {
    if (kDebugMode) debugPrint('$label ${redact(raw)}');
  }
}

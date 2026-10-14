/// Numéro mobile du chauffeur. Contrôle local avant l'appel, sur la seule
/// longueur (`phone_lengths` du pays, sans l'indicatif ni le 0 initial) ; le
/// serveur garde le dernier mot (PHONE_INVALID, PHONE_COUNTRY_MISMATCH).
class DriverPhone {
  DriverPhone._();

  /// Indicatifs des 4 marchés principaux, si `registration-options` n'a pas
  /// pu être chargé (écran de connexion).
  static const Map<String, String> dialCodes = {
    'MA': '+212',
    'DZ': '+213',
    'EG': '+20',
    'TN': '+216',
  };

  /// Longueurs connues, si le serveur n'envoie pas encore `phone_lengths`.
  static const Map<String, List<int>> knownLengths = {
    'MA': [9],
    'DZ': [9],
    'EG': [10],
    'TN': [8],
  };

  /// Chiffres arabes (٠١٢… et ۰۱۲…) → 0-9, séparateurs retirés, 00 → +.
  static String clean(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    var s = buffer.toString().replaceAll(RegExp(r'[\s\-.()\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    return s;
  }

  /// [lengths] vide : longueur raisonnable (6 à 14 chiffres), le serveur tranche.
  static DriverPhoneCheck check(String input,
      {required String dialCode, List<int> lengths = const []}) {
    if (dialCode.isEmpty) return const DriverPhoneCheck.invalid();
    var s = clean(input);
    if (s.isEmpty) return const DriverPhoneCheck.empty();

    if (s.startsWith('+')) {
      if (!s.startsWith(dialCode)) return const DriverPhoneCheck.countryMismatch();
      s = s.substring(dialCode.length);
    }
    if (!RegExp(r'^\d+$').hasMatch(s)) return const DriverPhoneCheck.invalid();
    if (s.startsWith('0')) s = s.substring(1); // 06… ou +212 06…
    final ok = lengths.isEmpty
        ? s.length >= 6 && s.length <= 14
        : lengths.contains(s.length);
    return ok ? DriverPhoneCheck.valid('$dialCode$s') : const DriverPhoneCheck.invalid();
  }
}

enum DriverPhoneIssue { none, empty, invalid, countryMismatch }

class DriverPhoneCheck {
  final String? e164;
  final DriverPhoneIssue issue;

  const DriverPhoneCheck.valid(String this.e164) : issue = DriverPhoneIssue.none;
  const DriverPhoneCheck.empty() : e164 = null, issue = DriverPhoneIssue.empty;
  const DriverPhoneCheck.invalid() : e164 = null, issue = DriverPhoneIssue.invalid;
  const DriverPhoneCheck.countryMismatch() : e164 = null, issue = DriverPhoneIssue.countryMismatch;

  bool get isValid => e164 != null;
}

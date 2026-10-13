/// Coordonnées du support client.
class SupportConstants {
  SupportConstants._();

  /// Numéro WhatsApp du support, format international sans « + » ni espaces
  /// (utilisé dans https://wa.me/<numéro>).
  static const String whatsAppNumber = '18648934663';

  /// Même numéro, lisible et composable (affichage, copie).
  static const String whatsAppDisplayNumber = '+1 864 893 4663';

  /// Lien wa.me ouvrant la conversation avec [message] prérempli.
  static Uri whatsAppUri(String message) => Uri.parse(
      'https://wa.me/$whatsAppNumber?text=${Uri.encodeComponent(message)}');
}

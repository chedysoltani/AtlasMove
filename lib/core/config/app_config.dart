class AppConfig {
  static const String appName = 'Flutter Project Structure';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'https://api.example.com';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  // Feature Flags
  static const bool enableLogging = true;
  static const bool enableAnalytics = false;

  // Support client
  /// Numéro WhatsApp Business du support, format international sans « + » ni
  /// espaces (utilisé dans https://wa.me/<numéro>). Valeur provisoire.
  static const String supportWhatsAppNumber = '216XXXXXXXX';
  /// Le bouton WhatsApp et le numéro ne s'affichent qu'une fois le vrai numéro renseigné.
  static bool get supportWhatsAppEnabled => !supportWhatsAppNumber.contains('X');
  static const String supportEmail = 'hello@atla.business';
}

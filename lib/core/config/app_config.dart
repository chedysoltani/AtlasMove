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
}

class AppConstants {
  // Route Names
  static const String homeRoute = '/home';
  static const String authRoute = '/auth';
  static const String profileRoute = '/profile';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userPreferencesKey = 'user_preferences';
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String userProfileEndpoint = '/user/profile';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxUsernameLength = 20;
}

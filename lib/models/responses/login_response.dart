import '../user.dart';

/// Modèle de réponse pour la connexion avec OTP
class LoginResponse {
  final bool success;
  final String authStep;
  final String message;
  final String email;
  final String sessionToken;
  final int expiresIn;
  final User? user;

  LoginResponse({
    required this.success,
    required this.authStep,
    required this.message,
    required this.email,
    required this.sessionToken,
    required this.expiresIn,
    this.user,
  });

  /// Crée une instance à partir d'un Map
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Gérer la structure de réponse réelle de l'API
    if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>;
      return LoginResponse(
        success: data['success'] ?? false,
        authStep: data['authStep'] ?? '',
        message: data['message'] ?? '',
        email: data['email'] ?? '',
        sessionToken: data['sessionToken'] ?? '',
        expiresIn: data['expiresIn'] ?? 0,
        user: data['user'] != null ? User.fromMap(data['user']) : null,
      );
    }
    
    // Gérer la structure directe (compatibilité)
    return LoginResponse(
      success: json['success'] ?? false,
      authStep: json['authStep'] ?? '',
      message: json['message'] ?? '',
      email: json['email'] ?? '',
      sessionToken: json['sessionToken'] ?? '',
      expiresIn: json['expiresIn'] ?? 0,
      user: json['user'] != null ? User.fromMap(json['user']) : null,
    );
  }

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    return {
      'data': {
        'success': success,
        'authStep': authStep,
        'message': message,
        'email': email,
        'sessionToken': sessionToken,
        'expiresIn': expiresIn,
        if (user != null) 'user': user!.toMap(),
      },
    };
  }

  @override
  String toString() {
    return 'LoginResponse(success: $success, authStep: $authStep, message: $message, email: $email)';
  }

  /// Vérifie si une étape OTP est requise
  bool get requiresOtp => authStep == 'otp';

  /// Vérifie si la connexion est complète
  bool get isComplete => success && user != null;
}

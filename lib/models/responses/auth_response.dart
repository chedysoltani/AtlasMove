import '../user.dart';

/// Modèle de réponse pour l'inscription/authentification
class AuthResponse {
  final User user;
  final String token;
  final String message;
  final bool success;
  final String? authStep;
  final String? sessionToken;
  final int? expiresIn;

  AuthResponse({
    required this.user,
    required this.token,
    required this.message,
    required this.success,
    this.authStep,
    this.sessionToken,
    this.expiresIn,
  });

  /// Crée une instance à partir d'un Map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Gérer la structure de réponse réelle de l'API
    if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>;
      return AuthResponse(
        user: User.fromMap(data['user'] ?? {}),
        token: data['token'] ?? data['sessionToken'] ?? '',
        message: data['message'] ?? '',
        success: data['success'] ?? true,
        authStep: data['authStep'],
        sessionToken: data['sessionToken'],
        expiresIn: data['expiresIn'],
      );
    }
    
    // Gérer la structure attendue (compatibilité)
    return AuthResponse(
      user: User.fromMap(json['user'] ?? {}),
      token: json['token'] ?? '',
      message: json['message'] ?? '',
      success: json['success'] ?? false,
      authStep: json['authStep'],
      sessionToken: json['sessionToken'],
      expiresIn: json['expiresIn'],
    );
  }

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    return {
      'data': {
        'user': user.toMap(),
        'token': token,
        'message': message,
        'success': success,
        if (authStep != null) 'authStep': authStep,
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (expiresIn != null) 'expiresIn': expiresIn,
      },
    };
  }

  @override
  String toString() {
    return 'AuthResponse(success: $success, message: $message, user: ${user.fullName}, authStep: $authStep)';
  }

  /// Vérifie si une étape OTP est requise
  bool get requiresOtp => authStep == 'otp';

  /// Vérifie si la connexion est complète
  bool get isComplete => success && authStep != 'otp';
}

/// Modèle de réponse pour les erreurs d'authentification
class AuthErrorResponse implements Exception {
  final String message;
  final List<String>? errors;
  final int statusCode;

  AuthErrorResponse({
    required this.message,
    this.errors,
    required this.statusCode,
  });

  factory AuthErrorResponse.fromJson(Map<String, dynamic> json, int statusCode) {
    // Gérer la structure de réponse réelle de l'API
    String message = 'Erreur inconnue';
    List<String>? errors;
    
    if (json.containsKey('data') && json['data'] != null) {
      final data = json['data'] as Map<String, dynamic>;
      message = data['message']?.toString() ?? 'Erreur inconnue';
      errors = data['errors']?.cast<String>();
    } else if (json.containsKey('message')) {
      final messageData = json['message'];
      if (messageData is List) {
        // Si message est un tableau, le joindre
        final messageList = messageData.map((e) => e.toString()).toList();
        message = messageList.join(', ');
        errors = messageList;
      } else {
        message = messageData.toString();
      }
      errors = json['errors']?.cast<String>();
    }
    
    return AuthErrorResponse(
      message: message,
      errors: errors,
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    return 'AuthErrorResponse(statusCode: $statusCode, message: $message, errors: $errors)';
  }
}

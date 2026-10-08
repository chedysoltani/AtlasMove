import '../user.dart';
import 'package:easy_localization/easy_localization.dart';

/// Modèle de réponse pour l'inscription/authentification
class AuthResponse {
  final User user;
  final String token;
  final String? refreshToken;
  final String message;
  final bool success;
  final String? authStep;
  final String? sessionToken;
  final int? expiresIn;

  AuthResponse({
    required this.user,
    required this.token,
    this.refreshToken,
    required this.message,
    required this.success,
    this.authStep,
    this.sessionToken,
    this.expiresIn,
  });

  /// Crée une instance à partir d'un Map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>;

      final nestedData = data['data'] is Map ? data['data'] as Map<String, dynamic> : null;
      final nestedUser = data['user'] is Map ? data['user'] as Map<String, dynamic> : null;

      // verify-otp renvoie l'utilisateur dans `data.user` : sans ce repli, le
      // rôle retombait sur 'client' et un livreur atterrissait sur le dashboard client.
      final String email = (data['email'] ?? nestedUser?['email'] ?? '').toString();
      final nameParts = email.split('@');
      final firstName = data['first_name'] ??
          nestedUser?['first_name'] ??
          nestedUser?['firstName'] ??
          nameParts[0];
      final lastName = data['last_name'] ??
          nestedUser?['last_name'] ??
          nestedUser?['lastName'] ??
          '';

      // Cherche l'id UUID dans plusieurs emplacements possibles de la réponse
      final userId = data['id'] ??
          data['userId'] ??
          data['user_id'] ??
          nestedUser?['id'] ??
          nestedData?['id'] ??
          nestedData?['userId'] ??
          email; // fallback: email (indique un bug backend si déclenché)

      final userMap = {
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': data['phone'] ?? nestedUser?['phone'] ?? '',
        'role': data['role'] ?? nestedUser?['role'] ?? 'client',
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': data['updated_at'] ?? DateTime.now().toIso8601String(),
      };

      return AuthResponse(
        user: User.fromMap(userMap),
        token: data['accessToken'] ?? data['access_token'] ?? data['token'] ?? data['sessionToken'] ?? '',
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
        message: data['message'] ?? '',
        success: data['success'] ?? true,
        authStep: data['authStep'],
        sessionToken: data['sessionToken'],
        expiresIn: data['expiresIn'],
      );
    }

    return AuthResponse(
      user: User.fromMap(json['user'] ?? {}),
      token: json['accessToken'] ?? json['access_token'] ?? json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? json['refresh_token'],
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
    String message = 'active_ride.unknown_error'.tr();
    List<String>? errors;
    
    if (json.containsKey('data') && json['data'] != null) {
      final data = json['data'] as Map<String, dynamic>;
      message = data['message']?.toString() ?? 'active_ride.unknown_error'.tr();
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

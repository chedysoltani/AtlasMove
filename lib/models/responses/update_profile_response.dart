import '../user.dart';

/// Modèle de réponse pour la mise à jour du profil utilisateur
class UpdateProfileResponse {
  final User user;
  final String message;
  final bool success;

  UpdateProfileResponse({
    required this.user,
    required this.message,
    required this.success,
  });

  /// Crée une instance à partir d'un Map
  factory UpdateProfileResponse.fromJson(Map<String, dynamic> json) {
    // Gérer la structure de réponse réelle de l'API
    if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>;
      return UpdateProfileResponse(
        user: User.fromMap(data['user'] ?? {}),
        message: data['message'] ?? 'Profil mis à jour avec succès',
        success: data['success'] ?? true,
      );
    }
    
    // Gérer la structure attendue (compatibilité)
    return UpdateProfileResponse(
      user: User.fromMap(json['user'] ?? {}),
      message: json['message'] ?? 'Profil mis à jour avec succès',
      success: json['success'] ?? false,
    );
  }

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    return {
      'data': {
        'user': user.toMap(),
        'message': message,
        'success': success,
      },
    };
  }

  @override
  String toString() {
    return 'UpdateProfileResponse(success: $success, message: $message, user: ${user.fullName})';
  }
}

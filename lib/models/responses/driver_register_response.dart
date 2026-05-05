import '../user.dart';

/// Réponse d'inscription pour un livreur
class DriverRegisterResponse {
  final String message;
  final User user;
  final String timestamp;
  final String method;
  final int statusCode;
  final String path;

  const DriverRegisterResponse({
    required this.message,
    required this.user,
    required this.timestamp,
    required this.method,
    required this.statusCode,
    required this.path,
  });

  /// Crée une instance à partir d'un Map
  factory DriverRegisterResponse.fromJson(Map<String, dynamic> json) {
    // Gérer la structure de réponse réelle de l'API
    if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>;
      return DriverRegisterResponse(
        message: data['message'] ?? 'Livreur registered successfully',
        user: User.fromMap(data['user'] ?? {}),
        timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
        method: json['method'] ?? 'POST',
        statusCode: json['statusCode'] ?? 201,
        path: json['path'] ?? '/api/v1/auth/register/livreur',
      );
    }
    
    // Gérer la structure attendue (compatibilité)
    return DriverRegisterResponse(
      message: json['message'] ?? 'Livreur registered successfully',
      user: User.fromMap(json['user'] ?? {}),
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      method: json['method'] ?? 'POST',
      statusCode: json['statusCode'] ?? 201,
      path: json['path'] ?? '/api/v1/auth/register/livreur',
    );
  }

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    return {
      'data': {
        'message': message,
        'user': user.toMap(),
      },
      'timestamp': timestamp,
      'method': method,
      'statusCode': statusCode,
      'path': path,
    };
  }

  @override
  String toString() {
    return 'DriverRegisterResponse(message: $message, user: ${user.email}, statusCode: $statusCode)';
  }
}

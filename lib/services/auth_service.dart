import '../core/network/http_client.dart';
import '../models/requests/register_request.dart';
import '../models/responses/auth_response.dart';
import '../models/responses/login_response.dart';

/// Exception de validation personnalisée pour le service
class ServiceValidationException implements Exception {
  final List<String> errors;
  
  ServiceValidationException(this.errors);
  
  @override
  String toString() => errors.join(', ');
}

/// Service pour gérer les opérations d'authentification
class AuthService {
  /// Inscription d'un nouveau client
  static Future<AuthResponse> registerClient(ClientRegisterRequest request) async {
    try {
      // Validation des données
      final validationError = request.validate();
      if (validationError != null) {
        throw ServiceValidationException([validationError]);
      }

      // Envoi de la requête
      final response = await HttpClient.post(
        '/auth/register/client',
        body: request.toJson(),
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      // Gérer la structure de réponse réelle de l'API
      bool isSuccess = false;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Vérifier si la réponse contient les données attendues
        if (responseData['data'] != null && responseData['data']['user'] != null) {
          isSuccess = true;
        } else if (responseData['success'] == true && responseData['user'] != null) {
          isSuccess = true;
        } else if (responseData['user'] != null) {
          isSuccess = true;
        }
      }
      
      if (isSuccess) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ServiceValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de l\'inscription: $e');
    }
  }

  /// Inscription d'un nouveau livreur
  static Future<AuthResponse> registerDelivery(DeliveryRegisterRequest request) async {
    try {
      // Validation des données
      final validationError = request.validate();
      if (validationError != null) {
        throw ServiceValidationException([validationError]);
      }

      // Envoi de la requête
      final response = await HttpClient.post(
        '/auth/register/delivery',
        body: request.toJson(),
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      if ((response.statusCode == 200 || response.statusCode == 201) && 
          (responseData['success'] == true || responseData['user'] != null)) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ServiceValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de l\'inscription: $e');
    }
  }

  /// Connexion d'un utilisateur
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      // Validation des données
      if (email.trim().isEmpty) {
        throw ServiceValidationException(['L\'email est requis']);
      }
      
      if (password.trim().isEmpty) {
        throw ServiceValidationException(['Le mot de passe est requis']);
      }

      // Envoi de la requête vers le bon endpoint
      final response = await HttpClient.post(
        '/m/auth/login',
        body: {
          'email': email.trim(),
          'password': password,
        },
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      // Gérer la structure de réponse réelle de l'API avec OTP
      bool isSuccess = false;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Vérifier si la réponse contient les données attendues
        if (responseData['data'] != null) {
          final data = responseData['data'] as Map<String, dynamic>;
          // Pour le login, on accepte success: true ou authStep: otp
          if (data['success'] == true || data['authStep'] != null) {
            isSuccess = true;
          }
        } else if (responseData['success'] == true && responseData['user'] != null) {
          isSuccess = true;
        } else if (responseData['user'] != null) {
          isSuccess = true;
        }
      }
      
      if (isSuccess) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ServiceValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de la connexion: $e');
    }
  }

  /// Déconnexion d'un utilisateur
  static Future<void> logout() async {
    try {
      await HttpClient.post('/auth/logout');
    } catch (e) {
      // La déconnexion peut échouer côté serveur mais l'utilisateur peut quand même être déconnecté localement
      print('Erreur lors de la déconnexion: $e');
    }
  }

  /// Rafraîchir le token d'accès
  static Future<AuthResponse> refreshToken() async {
    try {
      final response = await HttpClient.post('/auth/refresh');
      
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      if ((response.statusCode == 200 || response.statusCode == 201) && 
          (responseData['success'] == true || responseData['user'] != null || responseData['token'] != null)) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Erreur lors du rafraîchissement du token: $e');
    }
  }

  /// Demande de réinitialisation de mot de passe
  static Future<void> forgotPassword(String email) async {
    try {
      // Validation de l'email
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email.trim())) {
        throw ServiceValidationException(['Email invalide']);
      }

      await HttpClient.post(
        '/auth/forgot-password',
        body: {'email': email.trim()},
      );
    } on ServiceValidationException {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de la demande de réinitialisation: $e');
    }
  }

  /// Réinitialisation du mot de passe
  static Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      // Validation du mot de passe
      if (password.length < 8) {
        throw ServiceValidationException(['Le mot de passe doit contenir au moins 8 caractères']);
      }
      
      if (password != confirmPassword) {
        throw ServiceValidationException(['Les mots de passe ne correspondent pas']);
      }

      await HttpClient.post(
        '/auth/reset-password',
        body: {
          'token': token,
          'email': email,
          'password': password,
          'password_confirmation': confirmPassword,
        },
      );
    } on ServiceValidationException {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de la réinitialisation du mot de passe: $e');
    }
  }

  /// Vérification de l'email
  static Future<void> verifyEmail(String token) async {
    try {
      await HttpClient.post(
        '/auth/verify-email',
        body: {'token': token},
      );
    } catch (e) {
      throw NetworkException('Erreur lors de la vérification de l\'email: $e');
    }
  }

  /// Renvoyer l'email de vérification
  static Future<void> resendVerificationEmail(String email) async {
    try {
      await HttpClient.post(
        '/auth/resend-verification',
        body: {'email': email},
      );
    } catch (e) {
      throw NetworkException('Erreur lors de l\'envoi de l\'email de vérification: $e');
    }
  }

  /// Vérifier l'OTP pour compléter la connexion
  static Future<AuthResponse> verifyOtp({
    required String email,
    required String otp,
    required String sessionToken,
  }) async {
    try {
      // Validation des données
      if (email.trim().isEmpty) {
        throw ServiceValidationException(['L\'email est requis']);
      }
      
      if (otp.trim().isEmpty) {
        throw ServiceValidationException(['Le code OTP est requis']);
      }
      
      if (sessionToken.trim().isEmpty) {
        throw ServiceValidationException(['Le token de session est requis']);
      }

      // Envoi de la requête
      final response = await HttpClient.post(
        '/m/auth/verify-otp',
        body: {
          'email': email.trim(),
          'otpCode': otp.trim(), // Changé de 'otp' à 'otpCode'
          'sessionToken': sessionToken,
        },
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      bool isSuccess = false;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Vérifier si la réponse contient les données attendues
        if (responseData['data'] != null) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data['success'] == true && data['user'] != null) {
            isSuccess = true;
          }
        } else if (responseData['success'] == true && responseData['user'] != null) {
          isSuccess = true;
        } else if (responseData['user'] != null) {
          isSuccess = true;
        }
      }
      
      if (isSuccess) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ServiceValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      // Gestion améliorée des erreurs pour afficher les détails de l'API
      if (e is NetworkException) {
        // Si c'est une erreur 400, essayer d'extraire les détails de l'erreur
        if (e.message.contains('Erreur serveur (400)') && e.message.contains('Response Body:')) {
          try {
            final responseStart = e.message.indexOf('Response Body:');
            final responseJson = e.message.substring(responseStart + 'Response Body:'.length).trim();
            final errorData = responseJson.startsWith('{') ? responseJson : '{}';
            
            // Essayer de parser les détails de l'erreur
            if (errorData.contains('message')) {
              throw NetworkException('Erreur de validation: ${errorData}');
            }
          } catch (_) {
            // Si le parsing échoue, lancer l'erreur originale
          }
        }
        throw e;
      } else {
        throw e;
      }
    }
  }

  /// Demander un nouvel OTP
  static Future<LoginResponse> resendOtp({
    required String email,
    required String sessionToken,
  }) async {
    try {
      // Validation des données
      if (email.trim().isEmpty) {
        throw ServiceValidationException(['L\'email est requis']);
      }
      
      if (sessionToken.trim().isEmpty) {
        throw ServiceValidationException(['Le token de session est requis']);
      }

      // Envoi de la requête
      final response = await HttpClient.post(
        '/m/auth/resend-otp',
        body: {
          'email': email.trim(),
          'sessionToken': sessionToken,
        },
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      // Accepter les statuts 200, 201 (créé) et vérifier le contenu
      bool isSuccess = false;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Vérifier si la réponse contient les données attendues
        if (responseData['data'] != null) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data['success'] == true || data['authStep'] == 'otp') {
            isSuccess = true;
          }
        } else if (responseData['success'] == true) {
          isSuccess = true;
        }
      }
      
      if (isSuccess) {
        return LoginResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ServiceValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors du renvoi de l\'OTP: $e');
    }
  }
}

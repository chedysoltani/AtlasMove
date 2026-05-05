import '../core/network/http_client.dart';
import '../models/requests/update_profile_request.dart';
import '../models/responses/update_profile_response.dart';
import '../models/responses/auth_response.dart';

/// Service pour gérer les opérations de profil utilisateur
class ProfileService {
  /// Récupérer le profil de l'utilisateur connecté
  static Future<UpdateProfileResponse> getCurrentProfile() async {
    try {
      final response = await HttpClient.get('/users/profile');
      
      // Traitement de la réponse
      final responseData = response.json;
      
      if (response.statusCode == 200) {
        return UpdateProfileResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Erreur lors de la récupération du profil: $e');
    }
  }

  /// Mettre à jour le profil de l'utilisateur
  static Future<UpdateProfileResponse> updateProfile(UpdateProfileRequest request) async {
    try {
      // Validation des données
      final validationError = request.validate();
      if (validationError != null) {
        final errors = validationError.split('\n');
        // Créer une réponse HTTP fictive pour ValidationException
        final fakeResponse = HttpResponse(
          statusCode: 422,
          body: '{"errors": $errors}',
          headers: {},
        );
        throw ValidationException(errors, fakeResponse);
      }

      // Envoi de la requête
      final response = await HttpClient.put(
        '/users/current/profile',
        body: request.toJson(),
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      if (response.statusCode == 200) {
        return UpdateProfileResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors de la mise à jour du profil: $e');
    }
  }

  /// Télécharger une photo de profil
  static Future<Map<String, dynamic>> uploadProfilePicture(String filePath) async {
    try {
      // Utiliser multipart pour l'upload de fichier
      final response = await HttpClient.postMultipart(
        '/users/profile-picture',
        body: {
          'profile_picture': filePath,
        },
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Erreur lors du téléchargement de la photo: $e');
    }
  }

  /// Supprimer la photo de profil
  static Future<UpdateProfileResponse> deleteProfilePicture() async {
    try {
      final response = await HttpClient.delete('/users/profile-picture');
      
      // Traitement de la réponse
      final responseData = response.json;
      
      if (response.statusCode == 200) {
        return UpdateProfileResponse.fromJson(responseData);
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } catch (e) {
      throw NetworkException('Erreur lors de la suppression de la photo: $e');
    }
  }

  /// Changer le mot de passe
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Validation des données
      if (currentPassword.length < 8) {
        final fakeResponse = HttpResponse(statusCode: 422, body: '{"errors": ["Le mot de passe actuel doit contenir au moins 8 caractères"]}', headers: {});
        throw ValidationException(['Le mot de passe actuel doit contenir au moins 8 caractères'], fakeResponse);
      }
      
      if (newPassword.length < 8) {
        final fakeResponse = HttpResponse(statusCode: 422, body: '{"errors": ["Le nouveau mot de passe doit contenir au moins 8 caractères"]}', headers: {});
        throw ValidationException(['Le nouveau mot de passe doit contenir au moins 8 caractères'], fakeResponse);
      }

      // Envoi de la requête
      final response = await HttpClient.post(
        '/users/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPassword,
        },
      );

      // Traitement de la réponse
      final responseData = response.json;
      
      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw AuthErrorResponse.fromJson(responseData, response.statusCode);
      }
    } on ValidationException {
      rethrow;
    } on AuthErrorResponse {
      rethrow;
    } catch (e) {
      throw NetworkException('Erreur lors du changement de mot de passe: $e');
    }
  }

  /// Déconnecter l'utilisateur (supprimer le token)
  static Future<void> logout() async {
    try {
      await HttpClient.post('/auth/logout');
    } catch (e) {
      // La déconnexion peut échouer côté serveur mais l'utilisateur peut quand même être déconnecté localement
      print('Erreur lors de la déconnexion: $e');
    }
  }
}

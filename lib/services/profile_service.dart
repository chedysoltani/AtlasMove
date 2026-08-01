import 'dart:io';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/requests/update_profile_request.dart';
import '../models/responses/update_profile_response.dart';
import '../models/responses/auth_response.dart';
import 'location_tracking_service.dart';

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

  static const int _maxAvatarBytes = 5 * 1024 * 1024; // 5 MB
  static const _allowedAvatarExtensions = ['jpg', 'jpeg', 'png', 'gif'];

  /// Télécharger une photo de profil (PATCH /users/profile/avatar, multipart, champ "avatar")
  static Future<Map<String, dynamic>> uploadProfilePicture(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    if (!_allowedAvatarExtensions.contains(ext)) {
      final fakeResponse = HttpResponse(
          statusCode: 422,
          body: '{"errors": ["Format d\'image non supporté (jpg, jpeg, png, gif uniquement)"]}',
          headers: {});
      throw ValidationException(
          ['Format d\'image non supporté (jpg, jpeg, png, gif uniquement)'], fakeResponse);
    }

    final file = File(filePath);
    if (await file.exists() && await file.length() > _maxAvatarBytes) {
      final fakeResponse = HttpResponse(
          statusCode: 422,
          body: '{"errors": ["L\'image dépasse la taille maximale de 5 Mo"]}',
          headers: {});
      throw ValidationException(['L\'image dépasse la taille maximale de 5 Mo'], fakeResponse);
    }

    try {
      final response = await HttpClient.patchMultipart(
        '/users/profile/avatar',
        body: {
          'avatar': filePath,
        },
      );

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
      throw NetworkException('Erreur lors du téléchargement de la photo: $e');
    }
  }

  /// Supprimer la photo de profil (DELETE /users/profile/avatar)
  static Future<UpdateProfileResponse> deleteProfilePicture() async {
    try {
      final response = await HttpClient.delete('/users/profile/avatar');

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

  /// Résout une URL d'avatar potentiellement relative (ex: /uploads/avatars/xxx.png)
  /// en URL absolue, avec cache-busting optionnel pour forcer le rechargement de l'image.
  static String? resolveAvatarUrl(String? path, {bool bust = false}) {
    if (path == null || path.isEmpty) return null;
    final absolute = path.startsWith('http') ? path : '${HttpClient.host}$path';
    if (!bust) return absolute;
    final separator = absolute.contains('?') ? '&' : '?';
    return '$absolute${separator}t=${DateTime.now().millisecondsSinceEpoch}';
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

  /// Supprimer le compte — appel DELETE /m/auth/me puis nettoyage session
  static Future<void> deleteAccount(String password) async {
    // skipAutoRefresh=true : un 401 ici = mot de passe incorrect, pas token expiré
    await HttpClient.delete(
      '/m/auth/me',
      body: {'password': password},
      skipAutoRefresh: true,
    );
    LocationTrackingService().stopLocationTracking();
    await TokenStorage.clearTokens();
  }

  /// Déconnecter l'utilisateur — arrêt des services + nettoyage complet du storage
  static Future<void> logout() async {
    // 1. Stopper le tracking de position immédiatement
    LocationTrackingService().stopLocationTracking();

    // 2. Appel API (best-effort)
    try {
      await HttpClient.post('/auth/logout');
    } catch (_) {}

    // 3. Effacer tous les tokens ET poser le flag explicit_logout
    await TokenStorage.clearTokens();
  }
}

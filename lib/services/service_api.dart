import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/service_models.dart';
import '../core/config/api_config.dart';


class ServiceApi {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> _getHeaders(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AtlasMove/1.0 (Flutter)',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  static Future<PaginatedServicesResponse> getServices({
    required String token,
    int page = 1,
    int limit = 10,
    String? categoryId,
    String? transportType,
    String? pricingModel,
    bool activeOnly = true,
  }) async {
    try {
      // Simplification : appel sans paramètres pour obtenir tous les services
      final uri = Uri.parse('$_baseUrl/api/v1/services');
      
      print('DEBUG: API URL: $uri');
      print('DEBUG: API Headers: ${_getHeaders(token)}');

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PaginatedServicesResponse.fromJson(data);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<List<ServiceCategory>> getCategories({required String token}) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/categories');

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data
            .map((item) => ServiceCategory.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<ServiceCatalogue> getCatalogue({required String token}) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/catalogue');

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ServiceCatalogue.fromJson(data);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<ServiceAssignment> assignToService({
    required String token,
    required String serviceId,
    String? documentUrl,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/assignments/me');
      
      final request = AssignmentRequest(
        serviceId: serviceId,
        documentUrl: documentUrl,
      );

      final response = await http.post(
        uri,
        headers: _getHeaders(token),
        body: json.encode(request.toJson()),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ServiceAssignment.fromJson(data);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<PaginatedAssignmentsResponse> getMyAssignments({
    required String token,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl/api/v1/services/assignments/me').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PaginatedAssignmentsResponse.fromJson(data);
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<ServiceAssignment?> getCurrentAssignment({required String token}) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/assignments/me/current');

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ServiceAssignment.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<bool> cancelAssignment({
    required String token,
    required String assignmentId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/assignments/me/$assignmentId');

      final response = await http.delete(
        uri,
        headers: _getHeaders(token),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<String?> uploadDocument({
    required String token,
    required File file,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload/document');
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders(token)..remove('Content-Type'));
      
      final fileBytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'document',
        fileBytes,
        filename: file.path.split('/').last,
      );
      
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  static Future<File?> pickDocument() async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (result != null) {
        return File(result.path);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la sélection du fichier: $e');
    }
  }

  static Exception _handleApiError(http.Response response) {
    String message = 'Erreur serveur';
    
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      message = data['message'] as String? ?? data['error'] as String? ?? message;
    } catch (_) {
      message = 'Erreur ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown'}';
    }

    switch (response.statusCode) {
      case 400:
        return Exception('Requête invalide: $message');
      case 401:
        return Exception('Non autorisé: $message');
      case 403:
        return Exception('Accès interdit: $message');
      case 404:
        return Exception('Non trouvé: $message');
      case 409:
        return Exception('Conflit: $message');
      case 422:
        return Exception('Données invalides: $message');
      case 429:
        return Exception('Trop de requêtes: $message');
      case 500:
        return Exception('Erreur serveur interne: $message');
      default:
        return Exception('Erreur ${response.statusCode}: $message');
    }
  }

  static Exception _handleException(dynamic e) {
    if (e is Exception) return e;
    
    if (e is SocketException) {
      return Exception('Erreur de connexion: Vérifiez votre connexion internet');
    }
    
    if (e is HttpException) {
      return Exception('Erreur HTTP: ${e.message}');
    }
    
    if (e is FormatException) {
      return Exception('Erreur de format de réponse serveur');
    }
    
    return Exception('Erreur inattendue: $e');
  }
}

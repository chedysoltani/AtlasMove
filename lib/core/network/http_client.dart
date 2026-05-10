import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

/// HTTP Client pour gérer toutes les requêtes API
class HttpClient {
  static const String baseUrl = 'https://api.atla.business/api/v1';
  
  // Timeout settings
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  
  /// Headers par défaut pour toutes les requêtes
  static Future<Map<String, String>> _defaultHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AtlasMove/1.0 (Flutter)',
    };

    // Ajouter le bearer token si disponible
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      debugPrint('🔑 Token trouvé et ajouté aux headers');
    } else {
      debugPrint('❌ Aucun token trouvé dans le stockage');
    }

    return headers;
  }

  /// GET Request
  static Future<HttpResponse> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    return _makeRequest(
      'GET',
      endpoint,
      headers: headers,
      queryParams: queryParams,
    );
  }

  /// POST Request
  static Future<HttpResponse> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool isMultipart = false,
  }) async {
    return _makeRequest(
      'POST',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
      isMultipart: isMultipart,
    );
  }

  /// POST Request with multipart form data
  static Future<HttpResponse> postMultipart(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    return _makeRequest(
      'POST',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
      isMultipart: true,
    );
  }

  /// PUT Request
  static Future<HttpResponse> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    return _makeRequest(
      'PUT',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
    );
  }

  /// PATCH Request
  static Future<HttpResponse> patch(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    return _makeRequest(
      'PATCH',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
    );
  }

  /// DELETE Request
  static Future<HttpResponse> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    return _makeRequest(
      'DELETE',
      endpoint,
      headers: headers,
      queryParams: queryParams,
    );
  }

  /// Méthode principale pour faire les requêtes HTTP
  static Future<HttpResponse> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool isMultipart = false,
  }) async {
    try {
      // Construction de l'URL
      final uri = _buildUri(endpoint, queryParams);
      
      // Fusion des headers
      final defaultHeaders = await _defaultHeaders();
      final finalHeaders = {
        ...defaultHeaders,
        ...?headers,
      };

      debugPrint('🌐 API Request: $method $uri');
      debugPrint('📋 Headers: $finalHeaders');
      
      // Configuration de la requête
      var request;
      
      if (isMultipart) {
        // Pour les requêtes multipart (upload de fichiers)
        final multipartRequest = http.MultipartRequest(method, uri);
        
        // Ajouter les champs de formulaire
        body?.forEach((key, value) {
          if (value is String) {
            multipartRequest.fields[key] = value;
          }
        });
        
        request = multipartRequest;
        debugPrint('📦 Multipart Fields: ${multipartRequest.fields}');
      } else {
        // Pour les requêtes JSON normales
        request = http.Request(method, uri);
        request.headers.addAll(finalHeaders);
        
        if (body != null) {
          request.body = jsonEncode(body);
          debugPrint('📦 Body: ${jsonEncode(body)}');
        }
      }

      // Envoi de la requête avec timeout
      final streamedResponse = await request.send().timeout(_timeout);
      
      // Lecture de la réponse
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(_receiveTimeout);
      
      debugPrint('📊 Response Status: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      
      // Création de la réponse structurée
      final httpResponse = HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
      
      // Gestion des erreurs HTTP
      if (response.statusCode >= 400) {
        throw _handleHttpError(httpResponse);
      }
      
      return httpResponse;
    } on SocketException {
      debugPrint('❌ Network Error: No Internet Connection');
      throw NetworkException('Aucune connexion Internet. Vérifiez votre réseau.');
    } on TimeoutException {
      debugPrint('⏰ Timeout Error: Request timed out');
      throw NetworkException('La requête a expiré. Veuillez réessayer.');
    } catch (e) {
      debugPrint('💥 Unexpected Error: $e');
      throw NetworkException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Construction de l'URI avec les paramètres de requête
  static Uri _buildUri(String endpoint, Map<String, dynamic>? queryParams) {
    final url = '$baseUrl$endpoint';
    
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .where((e) => e.value != null)
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      return Uri.parse('$url?$queryString');
    }
    
    return Uri.parse(url);
  }

  /// Gestion des erreurs HTTP
  static ApiException _handleHttpError(HttpResponse response) {
    try {
      final errorData = jsonDecode(response.body);
      final message = errorData['message'] ?? errorData['error'] ?? 'Erreur serveur';
      
      switch (response.statusCode) {
        case 400:
          return BadRequestException(message, response);
        case 401:
          return UnauthorizedException(message, response);
        case 403:
          return ForbiddenException(message, response);
        case 404:
          return NotFoundException(message, response);
        case 422:
          final errors = errorData['errors'] is List ? 
            (errorData['errors'] as List).map((e) => e.toString()).toList() : 
            [errorData['message']?.toString() ?? 'Erreur de validation'];
          return ValidationException(errors.join(', '), response);
        case 429:
          return TooManyRequestsException(message, response);
        case 500:
          return ServerException('Erreur serveur interne', response);
        case 502:
          return ServerException('Service indisponible', response);
        case 503:
          return ServerException('Service en maintenance', response);
        default:
          return ServerException(message, response);
      }
    } catch (e) {
      return ServerException('Erreur serveur (${response.statusCode})', response);
    }
  }
}

/// Réponse HTTP structurée
class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  /// Récupérer le body comme JSON
  Map<String, dynamic> get json {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON response: $body');
    }
  }

  /// Vérifier si la réponse est réussie
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  @override
  String toString() {
    return 'HttpResponse(statusCode: $statusCode, body: $body)';
  }
}

/// Exceptions personnalisées pour les erreurs API
abstract class ApiException implements Exception {
  final String message;
  final HttpResponse? response;

  ApiException(this.message, [this.response]);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class BadRequestException extends ApiException {
  BadRequestException(String message, HttpResponse response) : super(message, response);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message, HttpResponse response) : super(message, response);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message, HttpResponse response) : super(message, response);
}

class NotFoundException extends ApiException {
  NotFoundException(String message, HttpResponse response) : super(message, response);
}

class ValidationException extends ApiException {
  ValidationException(dynamic errors, HttpResponse response) 
      : super(errors is List ? errors.join(', ') : errors.toString(), response);
}

class TooManyRequestsException extends ApiException {
  TooManyRequestsException(String message, HttpResponse response) : super(message, response);
}

class ServerException extends ApiException {
  ServerException(String message, HttpResponse response) : super(message, response);
}

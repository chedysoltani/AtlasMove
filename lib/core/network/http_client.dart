import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:easy_localization/easy_localization.dart';
import '../auth/jwt_utils.dart';
import '../storage/token_storage.dart';
import '../utils/safe_log.dart';

/// Devine le Content-Type d'un fichier à partir de son extension.
/// Le serveur rejette les uploads dont le Content-Type n'est pas explicitement
/// image/* — http.MultipartFile.fromPath() met application/octet-stream par défaut.
MediaType? _mediaTypeForFile(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'gif':
      return MediaType('image', 'gif');
    default:
      return null;
  }
}

/// HTTP Client pour gérer toutes les requêtes API
class HttpClient {
  static const String baseUrl = 'https://api.atla.business/api/v1';

  /// Hôte racine (sans /api/v1) — utilisé pour résoudre les URLs relatives
  /// renvoyées par le backend (ex: /uploads/avatars/xxx.png).
  static const String host = 'https://api.atla.business';

  /// Version envoyée au backend (en-tête X-App-Version et champ app_version des devices).
  static const String appVersion = '1.0.0';

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  static const Duration _refreshTimeout = Duration(seconds: 12);

  /// Marge avant l'expiration du JWT à partir de laquelle on rafraîchit.
  static const Duration _expirySkew = Duration(seconds: 60);

  /// Endpoints d'authentification : un 401 y signifie « identifiants invalides »
  /// (ou session inexistante), jamais « access token expiré » → pas de refresh,
  /// et surtout pas de déconnexion.
  static const List<String> _noRefreshPrefixes = [
    '/m/auth/login',
    '/m/auth/verify-otp',
    '/m/auth/resend-otp',
    '/m/auth/refresh',
    '/m/auth/forgot-password',
    '/m/auth/reset-password',
    '/auth/register',
    '/auth/forgot-password',
    '/auth/logout',
    '/m/auth/logout',
  ];

  static bool _isAuthEndpoint(String endpoint) =>
      _noRefreshPrefixes.any(endpoint.startsWith);

  // Un seul refresh à la fois : tous les appelants concurrents attendent le
  // même Future et reçoivent le même résultat (single-flight).
  static Future<RefreshOutcome>? _refreshInFlight;

  // Décalage horloge serveur − horloge téléphone, appris via l'en-tête `Date`.
  // Sans cela, un téléphone en avance/retard verrait des tokens « expirés » à tort.
  static Duration _serverClockOffset = Duration.zero;

  static DateTime get _serverNowUtc =>
      DateTime.now().toUtc().add(_serverClockOffset);

  static void _syncClock(Map<String, String> headers) {
    final date = headers['date'];
    if (date == null) return;
    try {
      _serverClockOffset = HttpDate.parse(date).difference(DateTime.now().toUtc());
    } catch (_) {}
  }

  /// Appelé quand la session expire définitivement (refresh token aussi invalide).
  /// Branché dans main.dart pour naviguer vers /login et déconnecter les sockets.
  static void Function()? onSessionExpired;

  /// Appelé après chaque refresh de token réussi.
  /// Branché dans main.dart pour reconnecter les sockets avec le nouveau token.
  static void Function()? onTokenRefreshed;

  /// Appelé quand le backend renvoie 403 pour accords légaux non acceptés.
  /// Branché dans main.dart pour naviguer vers /legal_consent.
  static void Function()? onLegalConsentRequired;
  
  /// Headers par défaut pour toutes les requêtes
  static Future<Map<String, String>> _defaultHeaders({bool authEndpoint = false}) async {
    final deviceId = await TokenStorage.getOrCreateDeviceId();
    final platform = Platform.isIOS ? 'ios' : 'android';

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AtlasMove/1.0 (Flutter)',
      'X-Device-Id': deviceId,
      'X-Platform': platform,
      'X-App-Version': appVersion,
    };

    // Préférence « Se souvenir de moi » : le backend peut adapter la durée de
    // vie du refresh token (login, vérification OTP, refresh).
    if (authEndpoint) {
      headers['X-Remember-Me'] = (await TokenStorage.getRememberMe()).toString();
    }

    // Bearer token : renouvelé ici s'il est expiré ou sur le point de l'être.
    // Sur les endpoints d'auth on envoie tel quel (pas de refresh pendant un login).
    final token = authEndpoint
        ? await TokenStorage.getAccessToken()
        : await getValidAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Access token utilisable : lu du stockage, rafraîchi (single-flight) s'il
  /// est expiré ou expire dans moins d'une minute (heure serveur).
  ///
  /// Un échec TRANSITOIRE du refresh (réseau, timeout, 5xx) renvoie le token
  /// courant : la requête partira et l'app réessaiera plus tard, sans déconnexion.
  /// Seul un refus explicite du serveur (401/403) invalide la session.
  static Future<String?> getValidAccessToken() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return token;

    final exp = JwtUtils.expiry(token);
    final needsRefresh = exp != null
        ? !exp.isAfter(_serverNowUtc.add(_expirySkew))
        : await TokenStorage.isAccessTokenExpiringSoon();
    if (!needsRefresh) return token;

    final outcome = await refreshSession();
    switch (outcome) {
      case RefreshOutcome.success:
        return TokenStorage.getAccessToken();
      case RefreshOutcome.invalid:
        await handleSessionInvalid();
        return null;
      case RefreshOutcome.transient:
        return token;
    }
  }

  /// Le token est-il encore valable pour au moins la marge de sécurité ?
  /// Un token illisible (non-JWT) est présumé valable : le serveur tranchera.
  static bool isAccessTokenFresh(String token) {
    final exp = JwtUtils.expiry(token);
    if (exp == null) return true;
    return exp.isAfter(_serverNowUtc.add(_expirySkew));
  }

  /// Le serveur a refusé le refresh token : session terminée, retour au login.
  static Future<void> handleSessionInvalid() async {
    await TokenStorage.clearTokens();
    onSessionExpired?.call();
  }

  /// Rafraîchit la session. Single-flight : N appelants simultanés = 1 seul appel réseau.
  static Future<RefreshOutcome> refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = future;
    return future;
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
    bool skipAutoRefresh = false,
  }) async {
    return _makeRequest(
      'POST',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
      isMultipart: isMultipart,
      skipAutoRefresh: skipAutoRefresh,
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

  /// PATCH Request with multipart form data
  static Future<HttpResponse> patchMultipart(
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
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool skipAutoRefresh = false,
  }) async {
    return _makeRequest(
      'DELETE',
      endpoint,
      headers: headers,
      body: body,
      queryParams: queryParams,
      skipAutoRefresh: skipAutoRefresh,
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
    bool isRetry = false,
    bool skipAutoRefresh = false,
  }) async {
    try {
      final authEndpoint = _isAuthEndpoint(endpoint);

      // Construction de l'URL
      final uri = _buildUri(endpoint, queryParams);

      // Fusion des headers (le refresh proactif du token se fait ici)
      final defaultHeaders = await _defaultHeaders(authEndpoint: authEndpoint);
      final finalHeaders = {
        ...defaultHeaders,
        ...?headers,
      };

      SafeLog.d('🌐 API Request: $method $uri');
      
      // Configuration de la requête
      var request;
      
      if (isMultipart) {
        // Pour les requêtes multipart (upload de fichiers)
        final multipartRequest = http.MultipartRequest(method, uri);
        multipartRequest.headers.addAll(finalHeaders);

        if (body != null) {
          for (final entry in body.entries) {
            final value = entry.value;
            if (value is String && value.isNotEmpty && !value.startsWith('http') && File(value).existsSync()) {
              // C'est un chemin de fichier local — l'envoyer comme fichier
              multipartRequest.files.add(
                await http.MultipartFile.fromPath(
                  entry.key,
                  value,
                  contentType: _mediaTypeForFile(value),
                ),
              );
            } else if (value != null) {
              multipartRequest.fields[entry.key] = value.toString();
            }
          }
        }

        request = multipartRequest;
        debugPrint('📦 Multipart Files: ${multipartRequest.files.map((f) => f.filename)}');
      } else {
        // Pour les requêtes JSON normales
        request = http.Request(method, uri);
        request.headers.addAll(finalHeaders);
        
        if (body != null) {
          request.body = jsonEncode(body);
          SafeLog.body('📦 Body:', request.body);
        }
      }

      // Envoi de la requête avec timeout
      final streamedResponse = await request.send().timeout(_timeout);
      
      // Lecture de la réponse
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(_receiveTimeout);
      
      _syncClock(response.headers);
      SafeLog.d('📊 Response Status: ${response.statusCode}');
      SafeLog.body('📄 Response Body:', response.body);
      
      // Création de la réponse structurée
      final httpResponse = HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
      
      // 401 sur une route protégée : UN refresh (partagé), puis on rejoue la requête.
      if (response.statusCode == 401 &&
          !isRetry &&
          !skipAutoRefresh &&
          !authEndpoint) {
        final sentAuth = finalHeaders['Authorization'];
        final current = await TokenStorage.getAccessToken();

        // Un autre appel a déjà renouvelé le token pendant que celui-ci était en
        // vol : on rejoue simplement avec le token à jour, sans nouveau refresh
        // (un second refresh consommerait inutilement un refresh token rotatif).
        final alreadyRefreshed = current != null &&
            current.isNotEmpty &&
            sentAuth != 'Bearer $current';

        if (!alreadyRefreshed) {
          final outcome = await refreshSession();
          if (outcome == RefreshOutcome.invalid) {
            await handleSessionInvalid();
            throw SessionExpiredException();
          }
          if (outcome == RefreshOutcome.transient) {
            // Réseau/serveur indisponible : PAS de déconnexion.
            throw NetworkException(
                'errors.unstable_connection'.tr());
          }
        }

        return _makeRequest(
          method, endpoint,
          headers: headers,
          body: body,
          queryParams: queryParams,
          isMultipart: isMultipart,
          isRetry: true,
        );
      }

      // 403 → accords légaux non acceptés
      if (response.statusCode == 403) {
        try {
          final errorBody = jsonDecode(response.body);
          final msg = (errorBody['message'] ?? errorBody['error'] ?? '').toString().toLowerCase();
          if (msg.contains('legal') || msg.contains('agreement') ||
              msg.contains('privacy') || msg.contains('terms') ||
              msg.contains('accepted') ||
              // French keywords
              msg.contains('politique') || msg.contains('confidentialit') ||
              msg.contains('conditions') || msg.contains('utilisation') ||
              msg.contains('accepter') || msg.contains('accords')) {
            onLegalConsentRequired?.call();
          }
        } catch (_) {}
      }

      // Gestion des autres erreurs HTTP
      if (response.statusCode >= 400) {
        throw _handleHttpError(httpResponse);
      }

      return httpResponse;
    } on SocketException {
      debugPrint('❌ Network Error: No Internet Connection');
      throw NetworkException('errors.no_internet'.tr());
    } on TimeoutException {
      debugPrint('⏰ Timeout Error: Request timed out');
      throw NetworkException('errors.timeout'.tr());
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('💥 Unexpected Error: $e');
      throw NetworkException('${'common.unknown_error'.tr()} $e');
    }
  }

  /// Appel réseau de refresh. Classe le résultat :
  /// - success   : nouveaux tokens (access ET refresh si rotation) sauvegardés ;
  /// - invalid   : le serveur a répondu 401/403 → refresh token expiré/révoqué ;
  /// - transient : tout le reste (hors-ligne, timeout, 5xx, 429, réponse illisible)
  ///               → la session est conservée, on réessaiera.
  static Future<RefreshOutcome> _doRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      SafeLog.d('🔄 Refresh: aucun refresh token stocké');
      return RefreshOutcome.invalid;
    }

    try {
      final deviceId = await TokenStorage.getOrCreateDeviceId();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await http.post(
        Uri.parse('$baseUrl/m/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $refreshToken',
          'X-Device-Id': deviceId,
          'X-Platform': platform,
          'X-App-Version': appVersion,
          'X-Remember-Me': (await TokenStorage.getRememberMe()).toString(),
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
          'deviceId': deviceId,
        }),
      ).timeout(_refreshTimeout);

      _syncClock(response.headers);
      SafeLog.d('🔄 Refresh status: ${response.statusCode}');

      final code = response.statusCode;
      if (code == 401 || code == 403) return RefreshOutcome.invalid;
      if (code != 200 && code != 201) return RefreshOutcome.transient;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = (data['data'] is Map ? data['data'] : null) ?? data;
      // Accepte camelCase et snake_case selon la config du backend
      final newAccess = payload['accessToken'] ?? payload['access_token'] ?? payload['token'];
      final newRefresh = payload['refreshToken'] ?? payload['refresh_token'];

      if (newAccess is String && newAccess.isNotEmpty) {
        // Rotation : si le serveur renvoie un nouveau refresh token il DOIT
        // remplacer l'ancien (réutiliser l'ancien peut révoquer toute la session).
        await TokenStorage.saveAuthTokens(
          accessToken: newAccess,
          refreshToken: newRefresh is String && newRefresh.isNotEmpty ? newRefresh : null,
        );
        onTokenRefreshed?.call();
        return RefreshOutcome.success;
      }

      SafeLog.d('❌ Refresh: réponse 2xx sans access token');
      return RefreshOutcome.transient;
    } catch (e) {
      SafeLog.d('🔄 Refresh transitoire (${e.runtimeType})');
      return RefreshOutcome.transient;
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
      final message = errorData['message'] ?? errorData['error'] ?? 'errors.server'.tr();
      
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
            [errorData['message']?.toString() ?? 'errors.validation'.tr()];
          return ValidationException(errors.join(', '), response);
        case 429:
          return TooManyRequestsException(message, response);
        case 500:
          return ServerException('errors.server_internal'.tr(), response);
        case 502:
          return ServerException('errors.service_unavailable'.tr(), response);
        case 503:
          return ServerException('errors.maintenance'.tr(), response);
        default:
          return ServerException(message, response);
      }
    } catch (e) {
      return ServerException('Erreur serveur (${response.statusCode})', response);
    }
  }
}

/// Résultat d'une tentative de refresh de session.
enum RefreshOutcome { success, invalid, transient }

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

/// Lancée quand le refresh token est aussi invalide → forcer la reconnexion
class SessionExpiredException extends ApiException {
  SessionExpiredException()
      : super('auth.session_expired'.tr());
}

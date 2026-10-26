import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/driver_onboarding.dart';

/// Erreur d'une route `/v2/driver/*` (contrat, section 5).
///
/// L'app branche sur [code] (stable) et affiche [message], déjà traduit par le
/// serveur ; à défaut (hors-ligne, réponse illisible), un texte local par code.
class DriverApiException implements Exception {
  final int? statusCode;
  final String code;
  final String serverMessage;

  /// Erreurs par champ : `fields.<champ>.message`.
  final Map<String, String> fieldErrors;
  final Map<String, dynamic> details;

  const DriverApiException({
    this.statusCode,
    required this.code,
    this.serverMessage = '',
    this.fieldErrors = const {},
    this.details = const {},
  });

  /// Pas de réponse du serveur (pas de réseau, délai dépassé, envoi coupé).
  static const networkCode = 'NETWORK_ERROR';

  bool get isNetwork => code == networkCode;

  /// Erreur qui justifie un nouvel essai automatique d'envoi de document.
  bool get isRetryable => isNetwork || code == 'UPLOAD_INTERRUPTED';

  int? get retryAfter {
    final v = details['retry_after'];
    return v is int ? v : int.tryParse(v?.toString() ?? '');
  }

  /// PHONE_INVALID : longueurs attendues pour le pays (`details.expected_lengths`).
  List<int> get expectedLengths {
    final v = details['expected_lengths'];
    return v is List ? v.map((e) => int.tryParse('$e')).whereType<int>().toList() : const [];
  }

  String get message {
    if (serverMessage.isNotEmpty) return serverMessage;
    final key = 'driver_v2.errors.$code';
    final local = key.tr();
    return local == key ? 'driver_v2.errors.generic'.tr() : local;
  }

  factory DriverApiException.fromBody(int statusCode, String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final map = Map<String, dynamic>.from(json);
        final error = map['error'] is Map ? Map<String, dynamic>.from(map['error']) : const <String, dynamic>{};
        final fields = <String, String>{};
        if (map['fields'] is Map) {
          (map['fields'] as Map).forEach((k, v) {
            final msg = v is Map ? v['message']?.toString() : v?.toString();
            if (msg != null && msg.isNotEmpty) fields[k.toString()] = msg;
          });
        }
        final message = map['message'];
        return DriverApiException(
          statusCode: statusCode,
          // Majuscules : certains codes arrivent en minuscules (ex.
          // legal_acceptance_required), l'app compare toujours en majuscules.
          code: (map['code'] ?? error['code'] ?? _codeForStatus(statusCode)).toString().toUpperCase(),
          serverMessage: message is String ? message : (error['message']?.toString() ?? ''),
          fieldErrors: fields,
          details: map['details'] is Map ? Map<String, dynamic>.from(map['details']) : const {},
        );
      }
    } catch (_) {}
    return DriverApiException(statusCode: statusCode, code: _codeForStatus(statusCode));
  }

  static String _codeForStatus(int status) {
    if (status == 401) return 'UNAUTHORIZED';
    if (status == 403) return 'FORBIDDEN';
    if (status == 404) return 'NOT_FOUND';
    if (status == 429) return 'RATE_LIMITED';
    if (status >= 500) return 'INTERNAL_ERROR';
    return 'VALIDATION_ERROR';
  }

  @override
  String toString() => 'DriverApiException($statusCode, $code)';
}

/// Routes du parcours chauffeur v2 (`{API_URL}/api/v1/v2/driver/...`).
///
/// Passe par [HttpClient] (jetons, X-Device-Id, X-Platform, refresh), en
/// ajoutant `Accept-Language` pour que les messages arrivent dans la langue de l'app.
class DriverOnboardingApi {
  DriverOnboardingApi._();

  static const Duration uploadTimeout = Duration(seconds: 120);

  /// Taille max d'un document : `files.max_size_bytes` de registration-options,
  /// seule source (confirmé par le backend) ; 10 Mo tant qu'elle n'est pas chargée.
  static int maxFileBytes = 10485760;
  static const int maxUploadRetries = 2;

  /// fr, ar ou en (les autres langues de l'app retombent sur fr, comme le serveur).
  static String get language {
    final code = (Intl.defaultLocale ?? 'fr').split(RegExp('[_-]')).first;
    return const {'ar', 'en'}.contains(code) ? code : 'fr';
  }

  static Map<String, String> get _headers => {'Accept-Language': language};

  static Map<String, dynamic> _data(HttpResponse response) {
    final json = response.json;
    return json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
  }

  static Future<Map<String, dynamic>> _call(Future<HttpResponse> Function() request) async {
    try {
      return _data(await request());
    } on ApiException catch (e) {
      final response = e.response;
      if (response != null) throw DriverApiException.fromBody(response.statusCode, response.body);
      if (e is SessionExpiredException) {
        throw const DriverApiException(statusCode: 401, code: 'REFRESH_TOKEN_INVALID');
      }
      throw const DriverApiException(code: DriverApiException.networkCode);
    } on FormatException {
      throw const DriverApiException(code: 'INTERNAL_ERROR');
    }
  }

  // ── Inscription ───────────────────────────────────────────────────────────

  static Future<DriverRegistrationOptions> registrationOptions() async {
    final options = DriverRegistrationOptions.fromJson(await _call(
        () => HttpClient.get('/v2/driver/registration-options', headers: _headers)));
    if (options.maxFileBytes > 0) maxFileBytes = options.maxFileBytes;
    return options;
  }

  /// [purpose] : `register` ou `login`. [email] : à l'inscription, l'adresse
  /// où le code est envoyé (ignorée par le serveur à la connexion).
  static Future<DriverOtpRequest> sendOtp({
    required String phone,
    required String country,
    required String purpose,
    String? email,
  }) async =>
      DriverOtpRequest.fromJson(await _call(() => HttpClient.post(
            '/v2/driver/auth/otp/send',
            headers: _headers,
            body: {
              'phone': phone,
              'country': country,
              'purpose': purpose,
              if (email != null && email.isNotEmpty) 'email': email,
            },
          )));

  /// Renvoie le `verification_token` (inscription uniquement). [email] : la
  /// même adresse qu'à `sendOtp`.
  static Future<String> verifyOtp({
    required String phone,
    required String country,
    required String requestId,
    required String code,
    String? email,
  }) async {
    final data = await _call(() => HttpClient.post(
          '/v2/driver/auth/otp/verify',
          headers: _headers,
          body: {
            'phone': phone,
            'country': country,
            if (email != null && email.isNotEmpty) 'email': email,
            'request_id': requestId,
            'otp_code': code,
          },
        ));
    return data['verification_token']?.toString() ?? '';
  }

  static Future<DriverSession> register({
    required String verificationToken,
    required String phone,
    required String country,
    String? email,
    required String city,
    required String firstName,
    required String lastName,
    required String vehicleType,
    String? serviceId,
    String? referralCode,
  }) async =>
      DriverSession.fromJson(await _call(() => HttpClient.post(
            '/v2/driver/auth/register',
            headers: _headers,
            body: {
              'verification_token': verificationToken,
              'phone': phone,
              'country': country,
              if (email != null && email.isNotEmpty) 'email': email,
              'city': city,
              'first_name': firstName,
              'last_name': lastName,
              'vehicle_type': vehicleType,
              if (serviceId != null) 'service_id': serviceId,
              if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
              'language': language,
              'accept_terms': true,
            },
          )));

  // ── Connexion ─────────────────────────────────────────────────────────────

  static Future<DriverSession> loginWithOtp({
    required String phone,
    required String country,
    required String requestId,
    required String code,
  }) async =>
      DriverSession.fromJson(await _call(() => HttpClient.post(
            '/v2/driver/auth/login',
            headers: _headers,
            body: {'phone': phone, 'country': country, 'request_id': requestId, 'otp_code': code},
          )));

  static Future<DriverSession> loginWithPassword({
    required String phone,
    required String country,
    required String password,
  }) async =>
      DriverSession.fromJson(await _call(() => HttpClient.post(
            '/v2/driver/auth/login',
            headers: _headers,
            body: {'phone': phone, 'country': country, 'password': password},
          )));

  // ── Suivi ─────────────────────────────────────────────────────────────────

  static Future<DriverProfile> me() async =>
      DriverProfile.fromJson(await _call(() => HttpClient.get('/v2/driver/me', headers: _headers)));

  // ── Documents ─────────────────────────────────────────────────────────────

  /// Envoie un document (champ multipart `file`). Jusqu'à [maxUploadRetries]
  /// nouveaux essais automatiques sur une erreur réseau ; [onProgress] reçoit
  /// la part envoyée (0 → 1), remise à zéro à chaque essai ; [onRetry] est
  /// appelé avant chaque nouvel essai (numéro de l'essai, nombre total).
  static Future<DriverProfile> uploadDocument(
    String type,
    File file, {
    required String contentType,
    void Function(double progress)? onProgress,
    void Function(int attempt, int total)? onRetry,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _uploadOnce(type, file, contentType, onProgress)
            .timeout(uploadTimeout);
      } on TimeoutException {
        if (attempt >= maxUploadRetries) {
          throw const DriverApiException(code: DriverApiException.networkCode);
        }
      } on DriverApiException catch (e) {
        if (!e.isRetryable || attempt >= maxUploadRetries) rethrow;
      }
      onRetry?.call(attempt + 2, maxUploadRetries + 1);
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }

  static Future<DriverProfile> _uploadOnce(
    String type,
    File file,
    String contentType,
    void Function(double progress)? onProgress, {
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${HttpClient.baseUrl}/v2/driver/documents/${Uri.encodeComponent(type)}');
    final token = await HttpClient.getValidAccessToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'AtlasMove/1.0 (Flutter)',
      'X-Device-Id': await TokenStorage.getOrCreateDeviceId(),
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
      'X-App-Version': HttpClient.appVersion,
      ..._headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      // Corps multipart construit puis relu par morceaux pour suivre la progression.
      final multipart = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType.parse(contentType),
        ));
      final total = multipart.contentLength;
      final body = multipart.finalize();

      final request = http.StreamedRequest('POST', uri)
        ..headers.addAll(headers)
        ..headers.addAll(multipart.headers)
        ..contentLength = total;

      var sent = 0;
      onProgress?.call(0);
      body.listen(
        (chunk) {
          sent += chunk.length;
          if (total > 0) onProgress?.call((sent / total).clamp(0.0, 1.0));
          request.sink.add(chunk);
        },
        onDone: request.sink.close,
        onError: request.sink.addError,
        cancelOnError: true,
      );

      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const DriverApiException(code: DriverApiException.networkCode);
    } on http.ClientException {
      throw const DriverApiException(code: DriverApiException.networkCode);
    } on HttpException {
      throw const DriverApiException(code: DriverApiException.networkCode);
    }

    // Jeton expiré entre-temps : un refresh, puis un seul nouvel essai.
    if (response.statusCode == 401 && !isRetryAfterRefresh) {
      final outcome = await HttpClient.refreshSession();
      if (outcome == RefreshOutcome.success) {
        return _uploadOnce(type, file, contentType, onProgress, isRetryAfterRefresh: true);
      }
      if (outcome == RefreshOutcome.invalid) {
        await HttpClient.handleSessionInvalid();
        throw const DriverApiException(statusCode: 401, code: 'REFRESH_TOKEN_INVALID');
      }
      throw const DriverApiException(code: DriverApiException.networkCode);
    }

    if (response.statusCode >= 400) {
      throw DriverApiException.fromBody(response.statusCode, response.body);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
      onProgress?.call(1);
      return DriverProfile.fromJson(
          data['driver'] is Map ? Map<String, dynamic>.from(data['driver']) : const {});
    } catch (e) {
      debugPrint('Driver document upload: réponse illisible (${e.runtimeType})');
      throw const DriverApiException(code: 'INTERNAL_ERROR');
    }
  }
}

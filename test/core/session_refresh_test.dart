import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:atlasmove/core/auth/auth_session.dart';
import 'package:atlasmove/core/auth/jwt_utils.dart';
import 'package:atlasmove/core/network/http_client.dart';
import 'package:atlasmove/core/storage/token_storage.dart';
import 'package:atlasmove/core/utils/safe_log.dart';

/// JWT non signé avec un `exp` donné (suffisant : le client ne vérifie pas la signature).
String jwt({required Duration validFor, String? role}) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().toUtc().add(validFor).millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'none'})}.${enc({'exp': exp, if (role != null) 'role': role})}.sig';
}

/// Faux backend : compte les appels et impose des tokens valides.
class FakeBackend {
  int refreshCalls = 0;
  int apiCalls = 0;
  String validAccess;
  String validRefresh;
  String nextAccess;
  String? nextRefresh;
  int refreshStatus = 200;
  bool refreshThrows = false;
  Duration refreshDelay = const Duration(milliseconds: 40);

  FakeBackend({
    required this.validAccess,
    this.validRefresh = 'refresh-1',
    required this.nextAccess,
    this.nextRefresh = 'refresh-2',
  });

  Future<http.Response> handle(http.BaseRequest req) async {
    final path = req.url.path;
    if (path.endsWith('/m/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(refreshDelay);
      if (refreshThrows) throw const SocketException('offline');
      if (refreshStatus != 200) return http.Response('{"message":"x"}', refreshStatus);
      validAccess = nextAccess;
      final body = <String, dynamic>{'data': {'accessToken': nextAccess, if (nextRefresh != null) 'refreshToken': nextRefresh}};
      if (nextRefresh != null) validRefresh = nextRefresh!;
      return http.Response(jsonEncode(body), 200);
    }
    if (path.endsWith('/m/auth/login')) {
      return http.Response('{"message":"Identifiants invalides"}', 401);
    }
    apiCalls++;
    final auth = req.headers['Authorization'];
    if (auth == 'Bearer $validAccess') return http.Response('{"ok":true}', 200);
    return http.Response('{"message":"Unauthorized"}', 401);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Faux flutter_secure_storage en mémoire ────────────────────────────────
  final store = <String, String>{};
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key!] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(store);
          case 'containsKey':
            return store.containsKey(key);
        }
        return null;
      },
    );
  });

  var sessionExpiredCalls = 0;
  setUp(() {
    store.clear();
    sessionExpiredCalls = 0;
    HttpClient.onSessionExpired = () => sessionExpiredCalls++;
    HttpClient.onTokenRefreshed = null;
  });

  Future<T> withBackend<T>(FakeBackend b, Future<T> Function() body) =>
      http.runWithClient(body, () => MockClient(b.handle));

  group('HttpClient — refresh de session', () {
    test('10 requêtes simultanées avec un access token expiré → UN seul refresh', () async {
      final expired = jwt(validFor: const Duration(minutes: -5));
      final fresh = jwt(validFor: const Duration(minutes: 15));
      await TokenStorage.saveAuthTokens(accessToken: expired, refreshToken: 'refresh-1', role: 'client');
      final backend = FakeBackend(validAccess: fresh, nextAccess: fresh);

      final results = await withBackend(backend, () => Future.wait(
            List.generate(10, (i) => HttpClient.get('/trips/$i')),
          ));

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(backend.refreshCalls, 1, reason: 'single-flight');
      expect(sessionExpiredCalls, 0);
      expect(await TokenStorage.getAccessToken(), fresh);
    });

    test('401 concurrents (token opaque) → UN seul refresh, toutes les requêtes rejouées', () async {
      // Token non-JWT : le client ne peut pas savoir qu'il est expiré, seul le 401 le lui dit.
      await TokenStorage.saveAuthTokens(accessToken: 'opaque-old', refreshToken: 'refresh-1', role: 'delivery');
      final backend = FakeBackend(validAccess: 'opaque-valid', nextAccess: 'opaque-new');
      backend.validAccess = 'opaque-new-not-yet'; // l'ancien est refusé jusqu'au refresh

      final results = await withBackend(backend, () => Future.wait(
            List.generate(10, (i) => HttpClient.get('/trips/$i')),
          ));

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(backend.refreshCalls, 1);
      expect(sessionExpiredCalls, 0);
    });

    test('rotation : le NOUVEAU refresh token remplace l\'ancien', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(seconds: -1)), refreshToken: 'refresh-1');
      final fresh = jwt(validFor: const Duration(minutes: 15));
      final backend = FakeBackend(validAccess: fresh, nextAccess: fresh, nextRefresh: 'refresh-2');

      await withBackend(backend, () => HttpClient.get('/trips'));

      expect(await TokenStorage.getRefreshToken(), 'refresh-2');
    });

    test('refresh en erreur 500 → PAS de déconnexion, tokens conservés', () async {
      final expired = jwt(validFor: const Duration(minutes: -5));
      await TokenStorage.saveAuthTokens(accessToken: expired, refreshToken: 'refresh-1', role: 'client');
      final backend = FakeBackend(validAccess: 'other', nextAccess: 'x')..refreshStatus = 500;

      await withBackend(backend, () async {
        await expectLater(HttpClient.get('/trips'), throwsA(isA<NetworkException>()));
      });

      expect(sessionExpiredCalls, 0);
      expect(await TokenStorage.getRefreshToken(), 'refresh-1');
      expect(await TokenStorage.getAccessToken(), expired);
    });

    test('mode avion pendant le refresh → PAS de déconnexion', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(minutes: -5)), refreshToken: 'refresh-1');
      final backend = FakeBackend(validAccess: 'other', nextAccess: 'x')..refreshThrows = true;

      await withBackend(backend, () async {
        await expectLater(HttpClient.get('/trips'), throwsA(isA<NetworkException>()));
      });

      expect(sessionExpiredCalls, 0);
      expect(await TokenStorage.hasSession(), isTrue);
    });

    test('refresh refusé (401) → déconnexion propre, UNE seule fois, sans boucle', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(minutes: -5)), refreshToken: 'refresh-revoked');
      final backend = FakeBackend(validAccess: 'other', nextAccess: 'x')..refreshStatus = 401;

      await withBackend(backend, () async {
        await expectLater(HttpClient.get('/trips'), throwsA(isA<SessionExpiredException>()));
      });

      expect(backend.refreshCalls, 1, reason: 'pas de boucle de refresh');
      expect(sessionExpiredCalls, greaterThanOrEqualTo(1));
      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
    });

    test('login avec mauvais mot de passe (401) → erreur normale, ni refresh ni déconnexion', () async {
      final backend = FakeBackend(validAccess: 'a', nextAccess: 'b');

      await withBackend(backend, () async {
        await expectLater(
          HttpClient.post('/m/auth/login', body: {'email': 'a@b.c', 'password': 'nope'}),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      expect(backend.refreshCalls, 0);
      expect(sessionExpiredCalls, 0);
    });
  });

  group('AuthSession.restore — démarrage à froid', () {
    test('aucune session → landing', () async {
      final r = await AuthSession.restore();
      expect(r.destination, BootDestination.landing);
    });

    test('access token valide + rôle → dashboard sans aucun appel réseau', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(minutes: 10)), refreshToken: 'r', role: 'delivery');
      final backend = FakeBackend(validAccess: 'x', nextAccess: 'y');

      final r = await withBackend(backend, AuthSession.restore);

      expect(r.destination, BootDestination.driver);
      expect(r.route, '/driver_main');
      expect(backend.refreshCalls + backend.apiCalls, 0);
    });

    test('access token expiré depuis des jours → refresh silencieux, reste connecté', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(days: -3)), refreshToken: 'refresh-1', role: 'client');
      final fresh = jwt(validFor: const Duration(minutes: 15));
      final backend = FakeBackend(validAccess: fresh, nextAccess: fresh);

      final r = await withBackend(backend, AuthSession.restore);

      expect(r.destination, BootDestination.client);
      expect(r.sessionExpired, isFalse);
      expect(backend.refreshCalls, 1);
    });

    test('hors-ligne au démarrage → reste connecté (pas de logout)', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(days: -3)), refreshToken: 'refresh-1', role: 'client');
      final backend = FakeBackend(validAccess: 'x', nextAccess: 'y')..refreshThrows = true;

      final r = await withBackend(backend, AuthSession.restore);

      expect(r.destination, BootDestination.client);
      expect(r.offline, isTrue);
      expect(await TokenStorage.hasSession(), isTrue);
    });

    test('refresh token révoqué → login avec message, tokens effacés', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(days: -3)), refreshToken: 'refresh-old', role: 'client');
      final backend = FakeBackend(validAccess: 'x', nextAccess: 'y')..refreshStatus = 401;

      final r = await withBackend(backend, AuthSession.restore);

      expect(r.destination, BootDestination.login);
      expect(r.sessionExpired, isTrue);
      expect(await TokenStorage.hasSession(), isFalse);
    });

    test('« Se souvenir de moi » décoché → session purgée au démarrage à froid', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(minutes: 10)), refreshToken: 'r', role: 'client');
      await TokenStorage.saveRememberMe(false);

      final r = await AuthSession.restore();

      expect(r.destination, BootDestination.landing);
      expect(await TokenStorage.hasSession(), isFalse);
    });

    test('rôle absent du stockage (flux OTP historique) → lu dans le JWT, pas de logout', () async {
      await TokenStorage.saveAuthTokens(
          accessToken: jwt(validFor: const Duration(minutes: 10), role: 'delivery'), refreshToken: 'r');

      final r = await AuthSession.restore();

      expect(r.destination, BootDestination.driver);
      expect(await TokenStorage.getUserRole(), 'delivery');
    });
  });

  group('Utilitaires', () {
    test('JwtUtils lit exp et role', () {
      final t = jwt(validFor: const Duration(minutes: 5), role: 'client');
      expect(JwtUtils.expiry(t)!.isAfter(DateTime.now().toUtc()), isTrue);
      expect(JwtUtils.role(t), 'client');
      expect(JwtUtils.expiry('pas-un-jwt'), isNull);
    });

    test('SafeLog.redact masque mots de passe et tokens', () {
      const raw = '{"email":"a@b.c","password":"Secr3t!","accessToken":"abc.def.ghi","otpCode":"123456"}';
      final out = SafeLog.redact(raw);
      expect(out.contains('Secr3t!'), isFalse);
      expect(out.contains('abc.def.ghi'), isFalse);
      expect(out.contains('123456'), isFalse);
      expect(out.contains('a@b.c'), isTrue);
    });
  });
}

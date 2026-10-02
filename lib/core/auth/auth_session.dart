import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/call_service.dart';
import '../../services/device_token_service.dart';
import '../../services/location_foreground_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../network/http_client.dart';
import '../storage/token_storage.dart';
import '../utils/safe_log.dart';
import 'jwt_utils.dart';

/// Où envoyer l'utilisateur au démarrage.
enum BootDestination { landing, login, client, driver }

class BootResult {
  final BootDestination destination;

  /// La session stockée a été refusée par le serveur (refresh token expiré/révoqué).
  final bool sessionExpired;

  /// Le refresh n'a pas pu aboutir (hors-ligne…) : on reste connecté et on réessaiera.
  final bool offline;

  const BootResult(this.destination, {this.sessionExpired = false, this.offline = false});

  String get route {
    switch (destination) {
      case BootDestination.client:
        return '/client_dashboard';
      case BootDestination.driver:
        return '/driver_main';
      case BootDestination.login:
        return '/login';
      case BootDestination.landing:
        return '/landing';
    }
  }
}

/// Cycle de vie de la session : restauration au démarrage, refresh proactif,
/// reprise au premier plan, reconnexion des sockets, déconnexion complète.
///
/// Règle d'or : seule une réponse explicite du serveur (401/403 sur le refresh)
/// ou une action de l'utilisateur termine la session. Réseau coupé, timeout,
/// 5xx ne déconnectent JAMAIS.
class AuthSession with WidgetsBindingObserver {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static const List<Duration> _retryBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  bool _observing = false;
  Timer? _proactiveTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// À appeler une fois dans main().
  void init() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResumed());
    } else if (state == AppLifecycleState.paused) {
      // Les timers Dart ne sont pas fiables en arrière-plan : on repart d'un
      // état propre au retour (onResumed re-évalue tout).
      _proactiveTimer?.cancel();
      _retryTimer?.cancel();
    }
  }

  // ── Restauration au démarrage ───────────────────────────────────────────────

  /// Lit la session, la valide et la renouvelle si besoin — puis indique où aller.
  static Future<BootResult> restore() async {
    try {
      if (await TokenStorage.wasExplicitlyLoggedOut() || !await TokenStorage.hasSession()) {
        return const BootResult(BootDestination.landing);
      }

      // « Se souvenir de moi » décoché : la session ne survit pas à la
      // fermeture de l'app → on la purge au démarrage à froid.
      if (!await TokenStorage.getRememberMe()) {
        await TokenStorage.clearTokens();
        return const BootResult(BootDestination.landing);
      }

      var offline = false;
      final access = await TokenStorage.getAccessToken();
      if (access == null || access.isEmpty || !HttpClient.isAccessTokenFresh(access)) {
        final outcome = await HttpClient.refreshSession().timeout(
          const Duration(seconds: 15),
          onTimeout: () => RefreshOutcome.transient,
        );
        if (outcome == RefreshOutcome.invalid) {
          await TokenStorage.clearTokens();
          return const BootResult(BootDestination.login, sessionExpired: true);
        }
        offline = outcome == RefreshOutcome.transient;
      }

      final role = await _resolveRole();
      if (role == null) {
        // Session valide mais rôle introuvable (ex. hors-ligne) : on ne
        // déconnecte pas, mais on ne peut pas choisir le bon tableau de bord.
        return BootResult(BootDestination.login, offline: offline);
      }
      instance.onTokensChanged();
      return BootResult(
        role == 'delivery' ? BootDestination.driver : BootDestination.client,
        offline: offline,
      );
    } catch (e) {
      // Une erreur inattendue au démarrage ne doit jamais effacer la session.
      SafeLog.d('AuthSession.restore: ${e.runtimeType}');
      return const BootResult(BootDestination.landing);
    }
  }

  /// Rôle mémorisé ; à défaut lu dans le JWT, puis dans le profil serveur.
  /// (Le flux OTP et l'inscription ne mémorisaient pas le rôle → l'app
  /// croyait l'utilisateur déconnecté à chaque relance.)
  static Future<String?> _resolveRole() async {
    var role = await TokenStorage.getUserRole();
    if (role != null && role.isNotEmpty) return role;

    final access = await TokenStorage.getAccessToken();
    role = access == null ? null : JwtUtils.role(access);
    if (role == null || role.isEmpty) {
      try {
        final profile = await ProfileService.getCurrentProfile().timeout(const Duration(seconds: 8));
        role = profile.user.role.name;
      } catch (_) {
        role = null;
      }
    }
    if (role != null && role.isNotEmpty) {
      role = (role == 'delivery' || role == 'driver' || role == 'livreur') ? 'delivery' : 'client';
      await TokenStorage.saveUserRole(role);
      return role;
    }
    return null;
  }

  // ── Refresh proactif, retour au premier plan ────────────────────────────────

  /// Retour au premier plan : renouvelle le token si besoin puis remet les sockets d'aplomb.
  Future<void> onResumed() async {
    if (!await TokenStorage.hasSession()) return;
    await ensureFresh();
    // `force: true` : après une mise en arrière-plan (écran éteint, changement
    // Wi-Fi/4G...), la socket peut rester bloquée "connectée" en façade alors
    // que la liaison est morte côté réseau — reconnecter seulement si
    // `.connected` ment ne suffit pas. Un aller-retour de reconnexion est
    // négligeable ; ne PAS le faire laissait l'appelé sourd à tout appel
    // entrant jusqu'au redémarrage de l'app (surtout sur téléphone physique).
    unawaited(NotificationService().connectWebSocket(force: true));
    unawaited(CallService().connectSocket(force: true));
  }

  /// Garantit un access token frais ; planifie un nouvel essai si le réseau manque.
  Future<void> ensureFresh() async {
    final token = await HttpClient.getValidAccessToken();
    if (token == null || token.isEmpty) return; // pas de session, ou invalidée (déjà gérée)

    if (HttpClient.isAccessTokenFresh(token)) {
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _scheduleProactive(token);
    } else {
      _scheduleRetry(); // le refresh a échoué de façon transitoire
    }
  }

  /// À appeler après un login / un refresh réussi.
  void onTokensChanged() {
    unawaited(() async {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) _scheduleProactive(token);
    }());
  }

  void _scheduleProactive(String token) {
    _proactiveTimer?.cancel();
    final exp = JwtUtils.expiry(token);
    if (exp == null) return;
    // On déclenche ~45 s avant l'expiration (dans la marge de 60 s de HttpClient).
    var delay = exp.difference(DateTime.now().toUtc()) - const Duration(seconds: 45);
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _proactiveTimer = Timer(delay, () => unawaited(ensureFresh()));
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _retryBackoff[_retryAttempt.clamp(0, _retryBackoff.length - 1)];
    _retryAttempt++;
    _retryTimer = Timer(delay, () => unawaited(ensureFresh()));
  }

  // ── Déconnexion ─────────────────────────────────────────────────────────────

  /// Déconnexion manuelle : supprime toujours la session, les tokens et le
  /// token FCM (côté serveur ET local). L'identifiant mémorisé pour le
  /// pré-remplissage est conservé si « Se souvenir de moi » est actif.
  Future<void> logout() async {
    _proactiveTimer?.cancel();
    _retryTimer?.cancel();
    _retryAttempt = 0;

    // 1. Services de fond (tracking GPS + foreground service)
    try {
      await LocationForegroundService.stop();
    } catch (_) {}

    // 2. Serveur — best effort. Le backend supprime la ligne device via
    //    `pushToken` dans POST /m/auth/logout (il n'existe pas de route DELETE) :
    //    sans lui, un téléphone déconnecté continue de recevoir les push du compte.
    final pushToken = await DeviceTokenService().currentToken();
    try {
      // Access token expiré : on tente un refresh d'abord (sans déclencher
      // l'écran « session expirée », qui n'a pas de sens pour un logout voulu).
      final access = await TokenStorage.getAccessToken();
      if (access != null && access.isNotEmpty && !HttpClient.isAccessTokenFresh(access)) {
        await HttpClient.refreshSession();
      }
      await HttpClient.post(
        '/m/auth/logout',
        body: {if (pushToken != null && pushToken.isNotEmpty) 'pushToken': pushToken},
        skipAutoRefresh: true,
      ).timeout(const Duration(seconds: 6));
    } catch (e) {
      SafeLog.d('logout API: ${e.runtimeType}');
    }
    // Même sans réponse du serveur (hors-ligne), le token FCM local est invalidé.
    await DeviceTokenService().invalidateLocalToken();

    // 3. Sockets
    NotificationService().disconnect();
    CallService().disconnect();

    // 4. Stockage local
    if (!await TokenStorage.getRememberMe()) {
      await TokenStorage.clearSavedIdentifier();
    }
    await TokenStorage.clearTokens();
  }
}

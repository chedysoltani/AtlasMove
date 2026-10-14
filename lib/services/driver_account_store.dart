import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_session.dart';
import '../core/storage/token_storage.dart';
import '../models/driver_onboarding.dart';
import 'call_service.dart';
import 'device_token_service.dart';
import 'driver_onboarding_analytics.dart';
import 'driver_onboarding_api.dart';
import 'notification_service.dart';

/// Profil du chauffeur connecté (`GET /v2/driver/me`) et aiguillage selon
/// son statut — seul endroit qui décide où envoyer un chauffeur : au
/// lancement, après connexion, après acceptation des CGU et au tap sur une
/// notification « dossier ».
class DriverAccountStore {
  DriverAccountStore._();
  static final DriverAccountStore instance = DriverAccountStore._();

  static const routeMain = '/driver_main';
  static const routeDossier = '/driver_dossier';
  static const routeSuspended = '/driver_suspended';
  static const routeLogin = '/login';
  static const routeLegal = '/legal_consent';
  static const routeClient = '/client_dashboard';

  /// Dernier statut connu, par compte (`<id>:<statut>`) : sert hors-ligne au
  /// lancement et à détecter les passages pending_review / active (Analytics).
  static const _lastStatusKey = 'driver_last_status_v1';

  final ValueNotifier<DriverProfile?> profile = ValueNotifier(null);

  /// Route d'un profil connu.
  static String routeFor(DriverProfile p) {
    if (p.isSuspended) return routeSuspended;
    if (p.isActive || p.nextAction == DriverNextAction.none) return routeMain;
    return routeDossier;
  }

  /// Recharge le profil et le publie.
  Future<DriverProfile> refresh() async {
    final p = await DriverOnboardingApi.me();
    await update(p);
    return p;
  }

  /// Rechargement en tâche de fond (notification) : une erreur est ignorée.
  Future<void> refreshQuietly() async {
    if (await TokenStorage.getUserRole() != 'delivery') return;
    try {
      await refresh();
    } catch (_) {}
  }

  /// Publie un profil reçu (me, register, login, envoi d'un document).
  Future<void> update(DriverProfile p) async {
    if (p.id.isEmpty) return;
    profile.value = p;
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_lastStatusKey);
      final current = '${p.id}:${p.accountStatus}';
      if (previous != current) {
        final sameAccount = previous != null && previous.startsWith('${p.id}:');
        // Passages observés sur ce compte (pas au premier chargement après mise à jour).
        if (sameAccount) {
          if (p.accountStatus == DriverAccountStatus.pendingReview) {
            DriverOnboardingAnalytics.registrationCompleted();
          } else if (p.accountStatus == DriverAccountStatus.active) {
            DriverOnboardingAnalytics.activated();
          }
        }
        await prefs.setString(_lastStatusKey, current);
      }
    } catch (e) {
      debugPrint('DriverAccountStore: ${e.runtimeType}');
    }
  }

  /// Où envoyer un chauffeur connecté. Ne lance jamais d'exception.
  ///
  /// - réponse du serveur → selon le statut ;
  /// - suspendu → écran d'information ; CGU à accepter → /legal_consent ;
  ///   compte client → tableau de bord client ; session refusée → /login ;
  /// - pas de réseau → d'après le dernier statut connu : seul un compte déjà
  ///   vu `active` va sur /driver_main, sinon « Mon dossier » (qui réessaie).
  Future<String> resolveHomeRoute() async {
    try {
      // Réseau très lent au lancement : on n'attend pas indéfiniment.
      return routeFor(await refresh().timeout(const Duration(seconds: 12)));
    } on DriverApiException catch (e) {
      switch (e.code) {
        case 'ACCOUNT_SUSPENDED':
          return routeSuspended;
        case 'LEGAL_ACCEPTANCE_REQUIRED':
          return routeLegal;
        case 'FORBIDDEN':
          return routeClient;
        case 'UNAUTHORIZED':
        case 'REFRESH_TOKEN_INVALID':
          return routeLogin;
      }
      if (!e.isNetwork) {
        DriverOnboardingAnalytics.registrationError(step: 'status', errorCode: e.code);
      }
      return await _lastKnownStatusIsActive() ? routeMain : routeDossier;
    } catch (_) {
      return await _lastKnownStatusIsActive() ? routeMain : routeDossier;
    }
  }

  Future<bool> _lastKnownStatusIsActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_lastStatusKey);
      final userId = await TokenStorage.getUserId();
      if (last == null || userId == null) return false;
      return last == '$userId:${DriverAccountStatus.active}';
    } catch (_) {
      return false;
    }
  }

  /// Session reçue de `register` ou `login` : jetons enregistrés comme pour la
  /// connexion actuelle, puis push et sockets branchés.
  Future<void> startSession(DriverSession session) async {
    // « Se souvenir de moi » : un chauffeur ne doit pas perdre sa session à la
    // fermeture de l'app (il reviendrait sur l'écran de connexion).
    await TokenStorage.saveRememberMe(true);
    await TokenStorage.saveAuthTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken.isEmpty ? null : session.refreshToken,
      userId: session.driver.id.isEmpty ? null : session.driver.id,
      role: 'delivery',
    );
    // Refresh par /v2/driver/auth/refresh : la session dure (30 jours) sans
    // que le chauffeur ait à se reconnecter.
    await TokenStorage.saveSessionApi(TokenStorage.sessionApiDriverV2);
    AuthSession.instance.onTokensChanged();
    unawaited(DeviceTokenService().registerDevice().catchError((_) {}));
    unawaited(NotificationService().connectWebSocket());
    unawaited(CallService().connectSocket());
    await update(session.driver);
  }

  /// Déconnexion : on oublie le profil affiché.
  void clear() => profile.value = null;
}

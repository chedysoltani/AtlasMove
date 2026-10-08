import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import '../core/storage/token_storage.dart';

/// Liens d'inscription des campagnes marketing.
///
///   https://atlasbusiness.online/register/client      (et www.)
///   atlasmove://register/client
///   → écran d'inscription client (`/signup`)
///   https://atlasbusiness.online/register/driver      (et www.)
///   atlasmove://register/driver
///   → écran d'inscription chauffeur (`/driver_register`)
///
/// Un lien reçu avant la fin du démarrage (démarrage à froid) est mis en
/// attente et consommé par SplashScreen. Un utilisateur déjà connecté reste sur
/// son écran habituel. Un lien inconnu est ignoré.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _hosts = {'atlasbusiness.online', 'www.atlasbusiness.online'};
  static const _routes = {'client': '/signup', 'driver': '/driver_register'};

  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingRoute;

  /// Vrai une fois que SplashScreen a choisi l'écran de départ : les liens
  /// suivants sont ouverts directement au lieu d'être mis en attente.
  bool _ready = false;

  /// À appeler une fois au démarrage, avant `runApp`. Le flux fournit aussi le
  /// lien qui a lancé l'app ; une erreur ici ne doit jamais bloquer le lancement.
  void init(GlobalKey<NavigatorState> navigatorKey) {
    if (_sub != null) return;
    _navigatorKey = navigatorKey;
    try {
      _sub = AppLinks().uriLinkStream.listen(_onLink, onError: (Object e) {
        debugPrint('DeepLink stream error: $e');
      });
    } catch (e) {
      debugPrint('DeepLink init error: $e');
    }
  }

  /// Route de l'écran ciblé par [uri], ou null si le lien n'est pas géré.
  @visibleForTesting
  static String? routeFor(Uri uri) {
    final List<String> segments;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == 'https' || scheme == 'http') && _hosts.contains(uri.host.toLowerCase())) {
      segments = uri.pathSegments;
    } else if (scheme == 'atlasmove') {
      // atlasmove://register/client : « register » est l'hôte de l'URI
      segments = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments];
    } else {
      return null;
    }
    final parts = segments.where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList();
    if (parts.length != 2 || parts[0] != 'register') return null;
    return _routes[parts[1]];
  }

  Future<void> _onLink(Uri uri) async {
    try {
      final route = routeFor(uri);
      if (route == null) {
        debugPrint('DeepLink ignoré : $uri');
        return;
      }
      if (!_ready) {
        _pendingRoute = route;
        return;
      }
      if (await _isLoggedIn()) return;
      _open(route);
    } catch (e) {
      debugPrint('DeepLink error: $e');
    }
  }

  /// Retourne puis efface le lien reçu pendant le démarrage. Appelé par
  /// SplashScreen (et par l'écran de langue au premier lancement), qui ne le
  /// consomme que si aucune session n'est restaurée.
  String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  bool get hasPendingRoute => _pendingRoute != null;

  /// Démarrage terminé : les liens suivants ouvrent l'écran directement.
  void markReady() => _ready = true;

  Future<bool> _isLoggedIn() async =>
      await TokenStorage.hasSession() && !await TokenStorage.wasExplicitlyLoggedOut();

  void _open(String route) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    // Ne pas empiler deux fois le même écran si le lien est ouvert de nouveau
    String? current;
    nav.popUntil((r) {
      current = r.settings.name;
      return true;
    });
    if (current == route) return;
    nav.pushNamed(route);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/auth/auth_session.dart';
import '../core/network/http_client.dart';
import 'call_service.dart';
import 'location_tracking_service.dart';
import 'notification_service.dart';
import 'remote_config_service.dart';

/// Ce que l'app doit afficher par-dessus tout le reste (voir AppGateOverlay).
enum AppGateMode {
  /// Rien : l'app fonctionne normalement.
  none,

  /// Version trop ancienne : écran bloquant « Mettre à jour ».
  forceUpdate,

  /// Maintenance : écran bloquant, aucun appel au serveur.
  maintenance,

  /// Maintenance pendant une course : simple bandeau, la course continue.
  maintenanceBanner,
}

/// Mise à jour obligatoire et mode maintenance, pilotés par Remote Config
/// (aucun backend nécessaire : Firebase répond même si notre serveur est en
/// panne). Un chauffeur en course n'est jamais interrompu : la mise à jour
/// attend la fin de la course, la maintenance se limite à un bandeau.
class AppGateService extends ChangeNotifier with WidgetsBindingObserver {
  AppGateService._();
  static final AppGateService instance = AppGateService._();

  /// Pendant une course, on revérifie à ce rythme si elle est terminée.
  static const _tripCheckEvery = Duration(seconds: 20);

  String _appVersion = '0.0.0';
  AppGateMode _mode = AppGateMode.none;
  Timer? _tripWatch;
  bool _started = false;

  AppGateMode get mode => _mode;

  @visibleForTesting
  set debugMode(AppGateMode value) {
    _mode = value;
    notifyListeners();
  }

  /// Aucun appel au serveur ni connexion temps réel (voir HttpClient).
  bool get blocksNetwork => _mode == AppGateMode.maintenance;

  /// À appeler une fois au démarrage, après RemoteConfigService.init.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      debugPrint('AppGate version: $e');
    }
    HttpClient.isNetworkBlocked = () => blocksNetwork;
    RemoteConfigService.instance.addListener(_update);
    WidgetsBinding.instance.addObserver(this);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _update();
    // Fin de maintenance ou nouvelle version minimale publiée pendant que
    // l'app dormait (le temps réel ne tourne pas en arrière-plan).
    unawaited(RemoteConfigService.instance.refresh());
  }

  void _update() {
    final rc = RemoteConfigService.instance;
    final onTrip = LocationTrackingService().activeTripId != null;
    final maintenance = rc.getBool(RemoteConfigService.maintenanceEnabled);
    final minimum = rc.getString(Platform.isIOS
        ? RemoteConfigService.minAppVersionIos
        : RemoteConfigService.minAppVersionAndroid);
    final updateNeeded = compareVersions(_appVersion, minimum) < 0;
    final next = decide(maintenance: maintenance, updateNeeded: updateNeeded, onTrip: onTrip);

    // Course en cours et quelque chose en attente : on surveille sa fin.
    final waiting = onTrip && (maintenance || updateNeeded);
    if (waiting) {
      _tripWatch ??= Timer.periodic(_tripCheckEvery, (_) => _update());
    } else {
      _tripWatch?.cancel();
      _tripWatch = null;
    }

    if (next == _mode) return;
    final wasBlocking = blocksNetwork;
    _mode = next;
    if (blocksNetwork && !wasBlocking) {
      NotificationService().disconnect();
      CallService().disconnect();
    } else if (!blocksNetwork && wasBlocking) {
      // Fin de maintenance : session vérifiée et connexions temps réel reprises.
      unawaited(AuthSession.instance.onResumed());
    }
    notifyListeners();
  }

  /// Message de maintenance de la console pour [languageCode] (texte simple,
  /// ou JSON {"fr": "…", "ar": "…"}) ; null : texte par défaut de l'app.
  String? maintenanceMessage(String languageCode) =>
      pickMessage(RemoteConfigService.instance.getString(RemoteConfigService.maintenanceMessage),
          languageCode);

  /// Heure de retour prévue (« 14h30 ») ; null si non renseignée.
  String? get maintenanceEta {
    final eta = RemoteConfigService.instance.getString(RemoteConfigService.maintenanceEta).trim();
    return eta.isEmpty ? null : eta;
  }

  // ── Logique pure (testée) ────────────────────────────────────────────────

  /// Maintenance avant mise à jour (rien ne sert de mettre à jour si le
  /// service est arrêté) ; en course, jamais d'écran bloquant.
  @visibleForTesting
  static AppGateMode decide({
    required bool maintenance,
    required bool updateNeeded,
    required bool onTrip,
  }) {
    if (maintenance) return onTrip ? AppGateMode.maintenanceBanner : AppGateMode.maintenance;
    if (updateNeeded && !onTrip) return AppGateMode.forceUpdate;
    return AppGateMode.none;
  }

  /// Compare deux versions « 1.0.9 » (le « +21 » est ignoré) : négatif si
  /// [a] < [b]. Une partie illisible compte pour 0.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.split('+').first.trim().split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  @visibleForTesting
  static String? pickMessage(String raw, String languageCode) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('{')) return text;
    try {
      final map = jsonDecode(text);
      if (map is Map) {
        final value = map[languageCode] ?? map['fr'] ?? map['en'];
        final s = value?.toString().trim();
        return (s == null || s.isEmpty) ? null : s;
      }
    } catch (_) {}
    return null;
  }
}

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config : valeurs réglables sans nouvelle version de l'app.
///
/// Chaque valeur a un défaut dans l'app ([_defaults]) : sans réseau, sans
/// Firebase ou avant le premier chargement, l'app fonctionne à l'identique.
/// Les valeurs chargées s'appliquent au lancement suivant (pas de changement
/// sous les yeux du chauffeur), sauf au tout premier lancement : rien n'est
/// encore en cache, elles sont donc activées dès leur arrivée, bien avant que
/// le nouveau chauffeur atteigne « Mon dossier ».
///
/// Prévient ses écouteurs à chaque activation de nouvelles valeurs.
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  // ── Clés (à créer avec les mêmes noms dans la console Firebase) ───────────

  /// Nombre affiché dans « +600 chauffeurs … » ; 0 masque la phrase.
  static const driverSocialProofCount = 'driver_social_proof_count';
  static const privacyPolicyUrl = 'privacy_policy_url';

  /// Documents progressifs (voir DriverDocumentsPlan) : interrupteur général,
  /// variante A/B (attribuée par Firebase A/B Testing) et types « pour commencer ».
  static const driverDocsProgressiveEnabled = 'driver_docs_progressive_enabled';
  static const driverDocsVariant = 'driver_docs_variant';
  static const driverDocsStartTypes = 'driver_docs_start_types';

  static const Map<String, Object> _defaults = {
    driverSocialProofCount: 600,
    privacyPolicyUrl: 'https://api.atla.business/legal/privacy-policy',
    // Désactivé tant que le backend n'accepte pas un dossier partiel.
    driverDocsProgressiveEnabled: false,
    driverDocsVariant: 'A',
    // TODO(documents progressifs) : ajouter le(s) type(s) de la pièce d'identité
    // (recto/verso ?) une fois confirmés par GET /v2/driver/me — corrigeable
    // dans Remote Config sans nouvelle version.
    driverDocsStartTypes: '["driving_license"]',
  };

  FirebaseRemoteConfig? _config;

  /// À appeler une fois au démarrage, après Firebase.initializeApp. N'attend
  /// pas le réseau : les valeurs déjà en cache sont activées tout de suite, les
  /// nouvelles sont chargées en arrière-plan pour le prochain lancement.
  Future<void> init() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await config.setDefaults(_defaults);
      final firstFetch = config.lastFetchStatus == RemoteConfigFetchStatus.noFetchYet;
      await config.activate();
      _config = config;
      notifyListeners();
      unawaited(_fetch(config, activate: firstFetch));
    } catch (e) {
      debugPrint('Remote Config init: $e');
    }
  }

  Future<void> _fetch(FirebaseRemoteConfig config, {required bool activate}) async {
    try {
      if (activate) {
        if (await config.fetchAndActivate()) notifyListeners();
      } else {
        await config.fetch();
      }
    } catch (e) {
      debugPrint('Remote Config fetch: $e');
    }
  }

  bool getBool(String key) {
    try {
      final config = _config;
      if (config != null) return config.getBool(key);
    } catch (_) {}
    return _defaults[key] as bool;
  }

  int getInt(String key) {
    try {
      final config = _config;
      if (config != null) return config.getInt(key);
    } catch (_) {}
    return _defaults[key] as int;
  }

  String getString(String key) {
    try {
      final value = _config?.getString(key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    return _defaults[key] as String;
  }

  int get socialProofCount => getInt(driverSocialProofCount);
  String get privacyUrl => getString(privacyPolicyUrl);
}

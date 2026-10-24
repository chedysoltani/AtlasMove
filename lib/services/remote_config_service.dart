import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config : valeurs réglables sans nouvelle version de l'app.
///
/// Chaque valeur a un défaut dans l'app ([_defaults]) : sans réseau, sans
/// Firebase ou avant le premier chargement, l'app fonctionne à l'identique.
/// Au démarrage, les valeurs en cache sont activées tout de suite, puis les
/// nouvelles dès leur arrivée. Pendant que l'app tourne, un changement publié
/// dans la console arrive en temps réel (maintenance, mise à jour obligatoire).
///
/// Prévient ses écouteurs à chaque activation de nouvelles valeurs.
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  // ── Clés (à créer avec les mêmes noms dans la console Firebase) ───────────

  /// Carte « Vos documents sont protégés » dans « Mon dossier » ; false la masque
  /// (ex. tant que le chiffrement du stockage n'est pas en place côté serveur).
  static const driverTrustCardEnabled = 'driver_trust_card_enabled';

  /// Nombre affiché dans « +600 chauffeurs … » ; 0 masque la phrase.
  static const driverSocialProofCount = 'driver_social_proof_count';
  static const privacyPolicyUrl = 'privacy_policy_url';

  /// Documents progressifs (voir DriverDocumentsPlan) : interrupteur général,
  /// variante A/B (attribuée par Firebase A/B Testing) et types « pour commencer ».
  static const driverDocsProgressiveEnabled = 'driver_docs_progressive_enabled';
  static const driverDocsVariant = 'driver_docs_variant';
  static const driverDocsStartTypes = 'driver_docs_start_types';

  /// Mise à jour obligatoire : version minimale par plateforme (« 1.0.9 ») ;
  /// « 0.0.0 » n'impose rien. Voir AppGateService.
  static const minAppVersionIos = 'min_app_version_ios';
  static const minAppVersionAndroid = 'min_app_version_android';

  /// Mode maintenance : interrupteur, message (texte simple, ou JSON par
  /// langue : {"fr": "…", "ar": "…"} ; vide = texte de l'app) et heure de
  /// retour affichée telle quelle (« 14h30 » ; vide = rien).
  static const maintenanceEnabled = 'maintenance_enabled';
  static const maintenanceMessage = 'maintenance_message';
  static const maintenanceEta = 'maintenance_eta';

  static const Map<String, Object> _defaults = {
    driverTrustCardEnabled: true,
    driverSocialProofCount: 600,
    privacyPolicyUrl: 'https://api.atla.business/legal/privacy-policy',
    // Désactivé tant que le backend n'accepte pas un dossier partiel.
    driverDocsProgressiveEnabled: false,
    driverDocsVariant: 'A',
    // Types confirmés par le backend (21/10) ; ne sert que si le serveur ne
    // donne pas l'étape de chaque document (documents[].stage).
    driverDocsStartTypes: '["id_card","driving_license"]',
    minAppVersionIos: '0.0.0',
    minAppVersionAndroid: '0.0.0',
    maintenanceEnabled: false,
    maintenanceMessage: '',
    maintenanceEta: '',
  };

  FirebaseRemoteConfig? _config;
  StreamSubscription<RemoteConfigUpdate>? _updates;

  /// À appeler une fois au démarrage, après Firebase.initializeApp. N'attend
  /// pas le réseau : les valeurs déjà en cache sont activées tout de suite, les
  /// nouvelles dès leur arrivée, puis chaque changement en temps réel.
  Future<void> init() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Court : la fin d'une maintenance doit être vue vite au lancement.
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 15),
      ));
      await config.setDefaults(_defaults);
      await config.activate();
      _config = config;
      notifyListeners();
      unawaited(_fetchAndActivate(config));
      _listenForUpdates(config);
    } catch (e) {
      debugPrint('Remote Config init: $e');
    }
  }

  Future<void> _fetchAndActivate(FirebaseRemoteConfig config) async {
    try {
      if (await config.fetchAndActivate()) notifyListeners();
    } catch (e) {
      debugPrint('Remote Config fetch: $e');
    }
  }

  /// Changements publiés dans la console pendant que l'app tourne.
  void _listenForUpdates(FirebaseRemoteConfig config) {
    _updates?.cancel();
    _updates = config.onConfigUpdated.listen(
      (_) async {
        try {
          await config.activate();
          notifyListeners();
        } catch (e) {
          debugPrint('Remote Config update: $e');
        }
      },
      onError: (Object e) => debugPrint('Remote Config temps réel: $e'),
    );
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

  /// Relit les valeurs du serveur (ex. au retour au premier plan), si
  /// l'intervalle minimal depuis le dernier chargement est écoulé.
  Future<void> refresh() async {
    final config = _config;
    if (config != null) await _fetchAndActivate(config);
  }

  bool get trustCardEnabled => getBool(driverTrustCardEnabled);
  int get socialProofCount => getInt(driverSocialProofCount);
  String get privacyUrl => getString(privacyPolicyUrl);
}

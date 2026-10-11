import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/permission_gate.dart';

/// Meta (Facebook) App Events, pour le suivi marketing dans Meta Events Manager.
///
/// Les évènements d'installation et d'ouverture de l'app sont envoyés
/// automatiquement par le SDK natif (auto-logging activé par défaut), à partir
/// des identifiants déclarés dans `strings.xml` / `AndroidManifest.xml` (Android)
/// et `Info.plist` (iOS). Aucun évènement personnalisé n'est envoyé pour l'instant :
/// [events] est exposé pour les ajouter plus tard depuis un point unique.
class MetaEventsService {
  MetaEventsService._();
  static final MetaEventsService instance = MetaEventsService._();

  final FacebookAppEvents events = FacebookAppEvents();

  bool _trackingRequested = false;

  /// À appeler une fois au démarrage. Vérifie que le SDK natif a bien chargé
  /// l'App ID ; une erreur ici ne doit jamais bloquer le lancement de l'app.
  Future<void> init() async {
    try {
      final appId = await events.getApplicationId();
      debugPrint('Meta App Events initialisé (App ID: $appId)');
    } catch (e) {
      debugPrint('Meta App Events init error: $e');
    }
  }

  /// iOS uniquement : demande l'autorisation de suivi (App Tracking
  /// Transparency) puis transmet la réponse au SDK Meta. Sans effet sur Android.
  ///
  /// À appeler une fois le premier écran affiché (après le splash) : iOS ignore
  /// la demande si l'app n'est pas encore active, d'où le court délai. Le
  /// dialogue système n'apparaît que si l'utilisateur n'a encore jamais répondu ;
  /// sinon on retransmet simplement le statut existant au SDK.
  ///
  /// Depuis le SDK iOS 17, Meta lit lui-même le statut ATT ; on aligne en plus
  /// la collecte de l'IDFA sur la réponse ([FacebookAppEvents.setAdvertiserIdCollectionEnabled]).
  Future<void> requestTrackingAuthorization() async {
    if (!Platform.isIOS || _trackingRequested) return;
    _trackingRequested = true;
    try {
      await Future.delayed(const Duration(seconds: 1));
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Via la file : une seule demande de permission système à la fois
        status = await PermissionGate.run(
          AppTrackingTransparency.requestTrackingAuthorization,
          timeout: const Duration(seconds: 120),
          onTimeout: TrackingStatus.notDetermined,
        );
      }
      await events.setAdvertiserIdCollectionEnabled(
          status == TrackingStatus.authorized);
      debugPrint('Meta App Events : statut ATT = ${status.name}');
    } catch (e) {
      debugPrint('Meta App Events ATT error: $e');
    }
  }
}

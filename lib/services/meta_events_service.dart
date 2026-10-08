import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

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
}

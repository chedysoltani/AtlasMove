import 'dart:async';
import 'dart:convert';

import '../models/driver_onboarding.dart';
import 'firebase_analytics_service.dart';
import 'remote_config_service.dart';

/// Documents progressifs : quels documents demander « pour commencer » et
/// lesquels « plus tard » (test A/B via Remote Config).
///
/// - Variante A (actuelle) : tous les documents ensemble.
/// - Variante B : [startTypes] d'abord, le reste dans une section « Plus tard ».
///
/// N'agit que sur l'affichage de « Mon dossier » : ce qui est obligatoire et le
/// statut du compte restent décidés par le backend. Désactivée par défaut
/// (`driver_docs_progressive_enabled` = false) tant que le backend n'accepte
/// pas un dossier partiel : la variante B ne s'applique alors à personne.
class DriverDocumentsPlan {
  final String variant;
  final Set<String> startTypes;

  const DriverDocumentsPlan({required this.variant, this.startTypes = const {}});

  static const variantA = 'A';
  static const variantB = 'B';
  static const userProperty = 'onboarding_variant';

  /// Plan en vigueur selon Remote Config.
  static DriverDocumentsPlan get current {
    final rc = RemoteConfigService.instance;
    final enabled = rc.getBool(RemoteConfigService.driverDocsProgressiveEnabled);
    final variant = rc.getString(RemoteConfigService.driverDocsVariant).trim().toUpperCase();
    if (!enabled || variant != variantB) return const DriverDocumentsPlan(variant: variantA);
    return DriverDocumentsPlan(
      variant: variantB,
      startTypes: parseTypes(rc.getString(RemoteConfigService.driverDocsStartTypes)),
    );
  }

  /// `["driving_license", …]` → ensemble de types ; valeur illisible → vide.
  static Set<String> parseTypes(String json) {
    try {
      final list = jsonDecode(json);
      if (list is List) {
        return list.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toSet();
      }
    } catch (_) {}
    return const {};
  }

  /// Variante réellement vue, en propriété utilisateur Analytics (jointe aux
  /// évènements du parcours). Rappelée à chaque activation Remote Config.
  static void publishVariant() => unawaited(
      FirebaseAnalyticsService.instance.setUserProperty(userProperty, current.variant));

  /// Documents répartis « pour commencer » / « plus tard », dans l'ordre du
  /// serveur. Variante A, ou aucun type reconnu dans la liste (type mal saisi
  /// dans Remote Config) : tout « pour commencer », rien « plus tard ».
  ({List<DriverDocument> start, List<DriverDocument> later}) split(List<DriverDocument> docs) {
    final start = docs.where((d) => startTypes.contains(d.type)).toList();
    if (variant != variantB || start.isEmpty) return (start: docs, later: const []);
    return (start: start, later: docs.where((d) => !startTypes.contains(d.type)).toList());
  }
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Google Analytics pour Firebase, pour le suivi marketing (campagnes Google Ads).
///
/// Les évènements `first_open` et `session_start` sont envoyés automatiquement
/// par le SDK natif dès que Firebase est initialisé ; `screen_view` est envoyé
/// par l'observateur de [navigatorObservers], branché sur le `MaterialApp`.
/// Les évènements personnalisés passent tous par ce service.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();

  /// Noms Analytics des écrans dont le nom de route ne convient pas tel quel.
  static const Map<String, String> _screenNames = {
    '/account_type': 'account_type_selection',
  };

  /// Accès paresseux : `FirebaseAnalytics.instance` exige que
  /// `Firebase.initializeApp()` ait déjà été appelé (voir main.dart).
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  /// Suivi automatique des écrans visités (évènement `screen_view`). Vide si
  /// Firebase n'a pas pu être initialisé : ça ne doit jamais bloquer l'app.
  late final List<NavigatorObserver> navigatorObservers = Firebase.apps.isEmpty
      ? const []
      : [
          FirebaseAnalyticsObserver(
            analytics: analytics,
            nameExtractor: (settings) => _screenNames[settings.name] ?? settings.name,
          ),
        ];

  /// Choix du type de compte à la fin du guide : `type` = `client` ou `driver`.
  Future<void> logAccountTypeSelected(String type) => _log(
        'account_type_selected',
        {'type': type},
      );

  /// Le client accepte l'offre d'un chauffeur (après succès de l'appel API).
  Future<void> logOfferAccepted({required String tripId, required String offerId, required double fare, required String currency}) =>
      _log('offer_accepted', {'trip_id': tripId, 'offer_id': offerId, 'value': fare, 'currency': currency});

  /// Le client refuse l'offre d'un chauffeur (après succès de l'appel API).
  Future<void> logOfferRejected({required String tripId, required String offerId, required double fare, required String currency}) =>
      _log('offer_rejected', {'trip_id': tripId, 'offer_id': offerId, 'value': fare, 'currency': currency});

  /// Évènement libre (parcours chauffeur : voir driver_onboarding_analytics.dart).
  Future<void> logEvent(String name, Map<String, Object> parameters) =>
      _log(name, parameters);

  /// Un évènement Analytics ne doit jamais bloquer ni faire planter l'app.
  Future<void> _log(String name, Map<String, Object> parameters) async {
    if (Firebase.apps.isEmpty) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics $name: $e');
    }
  }
}

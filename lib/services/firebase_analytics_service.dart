import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Google Analytics pour Firebase, pour le suivi marketing (campagnes Google Ads).
///
/// Les évènements `first_open` et `session_start` sont envoyés automatiquement
/// par le SDK natif dès que Firebase est initialisé ; `screen_view` est envoyé
/// par l'observateur de [navigatorObservers], branché sur le `MaterialApp`.
/// Aucun évènement personnalisé n'est envoyé pour l'instant : [analytics] est
/// exposé pour les ajouter plus tard depuis un point unique.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();

  /// Accès paresseux : `FirebaseAnalytics.instance` exige que
  /// `Firebase.initializeApp()` ait déjà été appelé (voir main.dart).
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  /// Suivi automatique des écrans visités (évènement `screen_view`). Vide si
  /// Firebase n'a pas pu être initialisé : ça ne doit jamais bloquer l'app.
  late final List<NavigatorObserver> navigatorObservers = Firebase.apps.isEmpty
      ? const []
      : [FirebaseAnalyticsObserver(analytics: analytics)];
}

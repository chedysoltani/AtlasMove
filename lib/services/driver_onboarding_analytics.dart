import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_analytics_service.dart';
import 'meta_events_service.dart';

/// Évènements du parcours d'inscription chauffeur, envoyés à Firebase Analytics
/// ET à Meta App Events. Aucune donnée personnelle (ni nom, ni téléphone, ni
/// identifiant) : seulement des catégories. Un échec d'envoi est ignoré.
class DriverOnboardingAnalytics {
  DriverOnboardingAnalytics._();

  static void registrationStarted() => _log('driver_registration_started');

  static void accountCreated({required String country, required String vehicleType}) =>
      _log('driver_account_created', {'country': country, 'vehicle_type': vehicleType});

  static void documentUploaded(String documentType) =>
      _log('driver_document_uploaded', {'document_type': documentType});

  /// [step] : `form`, `otp_send`, `otp_verify`, `register`, `login`, `upload`, `status`.
  static void registrationError({required String step, required String errorCode}) =>
      _log('driver_registration_error', {'step': step, 'error_code': errorCode});

  /// Le compte passe en `pending_review` (dossier complet).
  static void registrationCompleted() => _log('driver_registration_completed');

  static void activated() => _log('driver_activated');

  static void _log(String name, [Map<String, Object> parameters = const {}]) {
    // Jamais attendu par l'appelant : l'envoi ne doit rien bloquer.
    unawaited(_safely('Analytics $name',
        () => FirebaseAnalyticsService.instance.logEvent(name, parameters)));
    unawaited(_safely('Meta $name', () => MetaEventsService.instance.events.logEvent(
          name: name,
          parameters: parameters.isEmpty ? null : parameters,
        )));
  }

  static Future<void> _safely(String label, Future<void> Function() send) async {
    try {
      await send();
    } catch (e) {
      debugPrint('$label: $e');
    }
  }
}

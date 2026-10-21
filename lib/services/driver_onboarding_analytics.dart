import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ── Formulaire et code de vérification ─────────────────────────────────────

  /// Formulaire valide, envoi de la demande de code.
  static void signupFormSubmitted() => _log('driver_signup_form_submitted');

  /// Un évènement par champ en erreur (`phone`, `email`, `terms`…), local ou serveur.
  static void signupFormError(String field) =>
      _log('driver_signup_form_error', {'field': field});

  /// [purpose] : `register` ou `login` ; [channel] : `email` (ou `whatsapp`).
  static void otpSent({required String purpose, required String channel}) =>
      _log('driver_otp_sent', {'purpose': purpose, 'channel': channel});

  static void otpResent({required String purpose, required String channel}) =>
      _log('driver_otp_resent', {'purpose': purpose, 'channel': channel});

  static void otpVerified({required String purpose}) =>
      _log('driver_otp_verified', {'purpose': purpose});

  /// [stage] : `send` (code non parti) ou `verify` (code refusé) ;
  /// [reason] : code d'erreur en minuscules (`otp_invalid`, `otp_expired`, `network_error`…).
  static void otpFailed({required String purpose, required String stage, required String reason}) =>
      _log('driver_otp_failed', {'purpose': purpose, 'stage': stage, 'reason': _code(reason)});

  /// Code d'erreur stable seulement (jamais un message, qui pourrait contenir
  /// un e-mail ou un numéro) ; sinon `unknown`.
  static String _code(String code) =>
      RegExp(r'^[A-Za-z0-9_]{1,40}$').hasMatch(code) ? code.toLowerCase() : 'unknown';

  // ── Documents ──────────────────────────────────────────────────────────────

  /// Évènement historique, gardé tel quel pour la continuité des rapports.
  static void documentUploaded(String documentType) {
    _log('driver_document_uploaded', {'document_type': documentType});
    _log('document_uploaded', {'doc_type': documentType});
  }

  static void documentScreenViewed() => _log('document_screen_viewed');

  static void documentUploadStarted(String docType) =>
      _log('document_upload_started', {'doc_type': docType});

  /// [reason] : `size`, `format`, `network`, `server` ou `unknown`.
  static void documentUploadFailed(String docType, {required String reason, int? httpStatus}) =>
      _log('document_upload_failed', {
        'doc_type': docType,
        'reason': reason,
        if (httpStatus != null) 'http_status': httpStatus,
      });

  static void documentHelpWhatsAppClicked() => _log('document_help_whatsapp_clicked');

  static const _completedKey = 'driver_documents_completed_v1';

  /// Tous les documents obligatoires viennent d'être envoyés. Une seule fois
  /// par chauffeur et par appareil (pas après le remplacement d'un document
  /// refusé) : sert d'évènement d'optimisation des campagnes Meta.
  static Future<void> documentsCompleted(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getStringList(_completedKey) ?? const <String>[];
      if (done.contains(driverId)) return;
      await prefs.setStringList(_completedKey, [...done, driverId]);
    } catch (e) {
      debugPrint('Analytics driver_documents_completed: $e');
    }
    _log('driver_documents_completed');
  }

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

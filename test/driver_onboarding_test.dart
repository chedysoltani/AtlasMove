import 'dart:convert';

import 'package:atlasmove/models/driver_onboarding.dart';
import 'package:atlasmove/services/driver_account_store.dart';
import 'package:atlasmove/services/driver_onboarding_api.dart';
import 'package:atlasmove/services/push_notification_service.dart';
import 'package:atlasmove/utils/driver_phone.dart';
import 'package:flutter_test/flutter_test.dart';

DriverProfile _profile(String status, String nextAction) => DriverProfile.fromJson({
      'id': 'd1',
      'first_name': 'Sami',
      'last_name': 'Ben Ali',
      'phone': '+21620000001',
      'account_status': status,
      'next_action': nextAction,
    });

void main() {
  group('DriverPhone (longueur selon phone_lengths)', () {
    DriverPhoneCheck ma(String s) => DriverPhone.check(s, dialCode: '+212', lengths: [9]);

    test('Maroc : 0 initial, espaces, tirets, +212 0…, 00212, chiffres arabes', () {
      for (final input in [
        '06 12-34-56-78',
        '0612345678',
        '612345678',
        '+212 0612345678',
        '+212 6 12 34 56 78',
        '00212612345678',
        '٠٦١٢٣٤٥٦٧٨',
      ]) {
        expect(ma(input).e164, '+212612345678', reason: input);
      }
    });

    test('exemples du contrat : Tunisie, Algérie, Égypte, France, Allemagne', () {
      expect(DriverPhone.check('58 457 112', dialCode: '+216', lengths: [8]).e164, '+21658457112');
      expect(DriverPhone.check('+216 58 457 112', dialCode: '+216', lengths: [8]).e164, '+21658457112');
      expect(DriverPhone.check('0555 12 34 56', dialCode: '+213', lengths: [9]).e164, '+213555123456');
      expect(DriverPhone.check('01012345678', dialCode: '+20', lengths: [10]).e164, '+201012345678');
      expect(DriverPhone.check('+20 10 1234 5678', dialCode: '+20', lengths: [10]).e164, '+201012345678');
      expect(DriverPhone.check('06 12 34 56 78', dialCode: '+33', lengths: [9]).e164, '+33612345678');
      expect(DriverPhone.check('0151 1234 5678', dialCode: '+49', lengths: [10, 11]).e164, '+4915112345678');
    });

    test('refus : vide, mauvaise longueur, autre indicatif', () {
      expect(ma('').issue, DriverPhoneIssue.empty);
      expect(ma('06123').issue, DriverPhoneIssue.invalid);
      expect(DriverPhone.check('5845711', dialCode: '+216', lengths: [8]).issue, DriverPhoneIssue.invalid);
      expect(ma('+213551234567').issue, DriverPhoneIssue.countryMismatch);
    });

    test('sans phone_lengths : longueur raisonnable, le serveur tranche', () {
      expect(DriverPhone.check('612345678', dialCode: '+999').isValid, isTrue);
      expect(DriverPhone.check('123', dialCode: '+999').isValid, isFalse);
    });
  });

  group('Contrat du 14/10 : e-mail, sent_to, phone_lengths', () {
    test('registration-options : e-mail obligatoire et longueurs par pays', () {
      final o = DriverRegistrationOptions.fromJson({
        'countries': [
          {'code': 'TN', 'name': 'Tunisie', 'dial_code': '+216', 'phone_lengths': [8]},
          {'code': 'de', 'name': 'Allemagne', 'dial_code': '+49', 'phone_lengths': [10, 11]},
        ],
        'vehicle_types': [],
        'email': {'required': true},
        'otp': {'channel': 'email', 'available': true, 'code_length': 6},
      });
      expect(o.emailRequired, isTrue);
      expect(o.country('TN')!.phoneLengths, [8]);
      expect(o.country('DE')!.phoneLengths, [10, 11], reason: 'code ISO mis en majuscules');
    });

    test('ancien serveur (WhatsApp) : pas de champ e-mail', () {
      final o = DriverRegistrationOptions.fromJson({
        'countries': [],
        'vehicle_types': [],
        'otp': {'channel': 'whatsapp', 'available': true},
      });
      expect(o.emailRequired, isFalse);
    });

    test('otp/send : adresse masquée sent_to', () {
      final r = DriverOtpRequest.fromJson({
        'request_id': 'b71e', 'channel': 'email', 'sent_to': 'y•••••f@example.com', 'resend_after': 60,
      });
      expect(r.isEmail, isTrue);
      expect(r.sentTo, 'y•••••f@example.com');
    });

    test('PHONE_INVALID : expected_lengths', () {
      final e = DriverApiException.fromBody(400, jsonEncode({
        'code': 'PHONE_INVALID',
        'message': 'Numéro invalide.',
        'details': {'country': 'TN', 'expected_lengths': [8]},
      }));
      expect(e.expectedLengths, [8]);
    });
  });

  group('DriverApiException.fromBody', () {
    test('lit code, message traduit, champs et détails du contrat', () {
      final e = DriverApiException.fromBody(400, jsonEncode({
        'statusCode': 400,
        'code': 'OTP_INVALID',
        'message': 'Code incorrect. Il vous reste 4 essai(s).',
        'fields': {'otp_code': {'code': 'INVALID', 'message': 'Valeur invalide.'}},
        'details': {'remaining_attempts': 4},
      }));
      expect(e.code, 'OTP_INVALID');
      expect(e.message, 'Code incorrect. Il vous reste 4 essai(s).');
      expect(e.fieldErrors, {'otp_code': 'Valeur invalide.'});
      expect(e.details['remaining_attempts'], 4);
      expect(e.isRetryable, isFalse);
    });

    test('retry_after et nouvel essai sur UPLOAD_INTERRUPTED', () {
      final wait = DriverApiException.fromBody(429, jsonEncode({
        'code': 'OTP_RESEND_TOO_SOON', 'message': 'Patientez', 'details': {'retry_after': 42},
      }));
      expect(wait.retryAfter, 42);
      final cut = DriverApiException.fromBody(400, jsonEncode({'code': 'UPLOAD_INTERRUPTED', 'message': 'x'}));
      expect(cut.isRetryable, isTrue);
    });

    test('corps illisible : code déduit du statut HTTP', () {
      expect(DriverApiException.fromBody(503, '<html>').code, 'INTERNAL_ERROR');
      expect(DriverApiException.fromBody(401, '').code, 'UNAUTHORIZED');
    });
  });

  group('Aiguillage selon le statut', () {
    test('dossier, principal, suspendu', () {
      expect(DriverAccountStore.routeFor(_profile('pending_documents', 'UPLOAD_DOCUMENTS')), '/driver_dossier');
      expect(DriverAccountStore.routeFor(_profile('pending_documents', 'REPLACE_REJECTED_DOCUMENTS')), '/driver_dossier');
      expect(DriverAccountStore.routeFor(_profile('pending_review', 'WAIT_FOR_REVIEW')), '/driver_dossier');
      expect(DriverAccountStore.routeFor(_profile('rejected', 'CONTACT_SUPPORT')), '/driver_dossier');
      expect(DriverAccountStore.routeFor(_profile('active', 'NONE')), '/driver_main');
      expect(DriverAccountStore.routeFor(_profile('suspended', 'CONTACT_SUPPORT')), '/driver_suspended');
    });

    test('profil : documents et raison du refus', () {
      final p = DriverProfile.fromJson({
        'id': 'd1',
        'account_status': 'pending_documents',
        'next_action': 'REPLACE_REJECTED_DOCUMENTS',
        'review_sla_hours': 24,
        'documents': [
          {'type': 'driving_license', 'label': 'Permis de conduire', 'required': true,
           'status': 'rejected', 'rejection_reason': 'Permis illisible'},
          {'type': 'selfie', 'label': 'Selfie', 'required': false, 'status': 'missing'},
        ],
      });
      expect(p.documents.first.isRejected, isTrue);
      expect(p.documents.first.rejectionReason, 'Permis illisible');
      expect(p.documents.last.required, isFalse);
    });
  });

  group('Notifications dossier chauffeur', () {
    test('reconnaît driver_onboarding dans le push FCM', () {
      final data = PushNotificationService.driverOnboardingData({
        'event': 'new_notification',
        'payload': jsonEncode({
          'title': 'Document refusé',
          'message': '« Permis de conduire » a été refusé.',
          'metadata': {'category': 'driver_onboarding', 'event': 'document_rejected'},
        }),
      });
      expect(data?['type'], 'driver_onboarding');
      expect(data?['event'], 'document_rejected');
    });

    test('ignore les autres notifications', () {
      expect(PushNotificationService.driverOnboardingData({'type': 'new_ride'}), isNull);
      expect(PushNotificationService.driverOnboardingData({
        'event': 'new_notification',
        'payload': jsonEncode({'metadata': {'category': 'trip'}}),
      }), isNull);
    });
  });
}

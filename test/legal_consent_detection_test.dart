import 'package:atlasmove/core/network/http_client.dart';
import 'package:atlasmove/services/driver_onboarding_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Refus « accords légaux non acceptés » (403)', () {
    test('réponse réelle du backend (code en minuscules) : écran de consentement', () {
      // Corps renvoyé par LegalAgreementsInterceptor depuis le 13/10 (audit backend du 26/10).
      final body = {
        'statusCode': 403,
        'message': 'Vous devez accepter la politique de confidentialité et les conditions '
            "d'utilisation pour accéder à ce service.",
        'code': 'legal_acceptance_required',
        'error': {'code': 'legal_acceptance_required', 'message': '…', 'details': {}},
      };
      expect(HttpClient.isLegalConsentRefusal(body), isTrue);
    });

    test('code en majuscules ou seulement dans error.code', () {
      expect(HttpClient.isLegalConsentRefusal({'code': 'LEGAL_ACCEPTANCE_REQUIRED'}), isTrue);
      expect(HttpClient.isLegalConsentRefusal({
        'error': {'code': 'legal_acceptance_required'}
      }), isTrue);
    });

    test('ancien serveur sans code : on se fie au message', () {
      expect(HttpClient.isLegalConsentRefusal({
        'message': 'You must accept the privacy policy and terms of use',
      }), isTrue);
    });

    test('autre refus avec un code : jamais pris pour un refus légal', () {
      expect(HttpClient.isLegalConsentRefusal({
        'code': 'ACCOUNT_SUSPENDED',
        'message': "Compte suspendu pour non-respect des conditions d'utilisation",
      }), isFalse);
      expect(HttpClient.isLegalConsentRefusal({'code': 'COMMISSION_UNPAID'}), isFalse);
    });

    test('corps illisible ou sans rapport', () {
      expect(HttpClient.isLegalConsentRefusal('pas une map'), isFalse);
      expect(HttpClient.isLegalConsentRefusal({'message': 'Forbidden'}), isFalse);
    });
  });

  test('erreurs chauffeur : codes normalisés en majuscules', () {
    final e = DriverApiException.fromBody(
        403, '{"code":"legal_acceptance_required","message":"Vous devez accepter…"}');
    expect(e.code, 'LEGAL_ACCEPTANCE_REQUIRED');
  });
}

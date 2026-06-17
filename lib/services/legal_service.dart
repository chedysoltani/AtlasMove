import '../core/network/http_client.dart';

class LegalService {
  static Future<void> acceptPrivacyPolicy() async {
    final response = await HttpClient.post(
      '/users/accept-privacy-policy',
      body: {
        'version': '1.0',
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!response.isSuccess) {
      throw Exception('Erreur lors de l\'acceptation de la politique de confidentialité');
    }
  }

  static Future<void> acceptTermsAndConditions() async {
    final response = await HttpClient.post(
      '/users/accept-terms-and-conditions',
      body: {
        'version': '1.0',
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!response.isSuccess) {
      throw Exception('Erreur lors de l\'acceptation des conditions d\'utilisation');
    }
  }
}

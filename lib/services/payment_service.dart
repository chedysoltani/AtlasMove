import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../core/network/http_client.dart';

class PaymentService {
  static const String _tag = 'PaymentService';

  /// Crée un PaymentIntent sur le backend et renvoie le client_secret
  static Future<String?> createPaymentIntent({
    required double amount,
    required String currency,
    required String tripId,
  }) async {
    debugPrint('[$_tag] Creating PaymentIntent for trip $tripId: $amount $currency');
    
    try {
      // MODE MOCK pour les tests (à commenter quand le backend est prêt)
      // return "pi_mock_secret_${DateTime.now().millisecondsSinceEpoch}";

      final response = await HttpClient.post('/payments/create-intent', body: {
        'amount': (amount * 100).toInt(), // Stripe utilise les centimes
        'currency': currency.toLowerCase(),
        'trip_id': tripId,
      });

      if (response.isSuccess) {
        final data = response.json;
        final clientSecret = data['client_secret'];
        debugPrint('[$_tag] PaymentIntent created successfully');
        return clientSecret;
      } else {
        debugPrint('[$_tag] Error creating PaymentIntent: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[$_tag] Exception creating PaymentIntent: $e');
      return null;
    }
  }

  /// Initialise le Stripe Payment Sheet
  static Future<bool> initPaymentSheet({
    required String clientSecret,
    String merchantDisplayName = 'AtlasMove',
  }) async {
    debugPrint('[$_tag] Initializing Payment Sheet');
    
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF4F8EF7),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
              shadow: PaymentSheetShadowParams(color: Colors.black12),
            ),
          ),
        ),
      );
      debugPrint('[$_tag] Payment Sheet initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[$_tag] Error initializing Payment Sheet: $e');
      return false;
    }
  }

  /// Affiche le Payment Sheet et attend le résultat
  static Future<PaymentResult> presentPaymentSheet() async {
    debugPrint('[$_tag] Presenting Payment Sheet');
    
    try {
      await Stripe.instance.presentPaymentSheet();
      debugPrint('[$_tag] Payment success');
      return PaymentResult.success;
    } on StripeException catch (e) {
      if (e.error.localizedMessage?.contains('cancelled') ?? false) {
        debugPrint('[$_tag] Payment cancelled by user');
        return PaymentResult.cancelled;
      }
      debugPrint('[$_tag] Stripe error: ${e.error.localizedMessage}');
      return PaymentResult.failed;
    } catch (e) {
      debugPrint('[$_tag] Unexpected error presenting Payment Sheet: $e');
      return PaymentResult.failed;
    }
  }
}

enum PaymentResult { success, failed, cancelled }

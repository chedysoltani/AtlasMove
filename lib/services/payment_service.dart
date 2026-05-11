import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../core/network/http_client.dart';
import '../models/payment_models.dart';

class PaymentService {
  static const String _tag = 'PaymentService';

  /// Récupère l'historique des paiements
  static Future<PaymentHistoryResponse?> getPaymentHistory({int page = 1, int limit = 20}) async {
    try {
      final response = await HttpClient.get('/m/payments', queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      if (response.isSuccess) {
        return PaymentHistoryResponse.fromJson(response.json);
      }
      return null;
    } catch (e) {
      debugPrint('[$_tag] Error fetching payment history: $e');
      return null;
    }
  }

  /// Récupère les paiements en cours de traitement (pour le polling)
  static Future<List<PaymentResponseDto>> getProcessingPayments() async {
    try {
      final response = await HttpClient.get('/m/payments', queryParams: {
        'status': 'processing',
        'limit': '5',
      });

      if (response.isSuccess) {
        final payload = response.json['data'] as Map<String, dynamic>;
        final list = payload['data'] as List;
        return list.map((e) => PaymentResponseDto.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[$_tag] Error fetching processing payments: $e');
      return [];
    }
  }

  /// Récupère le client_secret pour confirmer un paiement 3DS
  static Future<String?> getConfirmClientSecret(String paymentId) async {
    try {
      final response = await HttpClient.get('/m/payments/$paymentId/confirm');
      if (response.isSuccess) {
        return response.json['client_secret'];
      }
      return null;
    } catch (e) {
      debugPrint('[$_tag] Error getting confirm client secret: $e');
      return null;
    }
  }

  /// Gère le flux de confirmation 3DS via le SDK Stripe
  static Future<void> handle3DSConfirmation(String clientSecret) async {
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
    } catch (e) {
      debugPrint('[$_tag] Error during 3DS confirmation: $e');
      rethrow;
    }
  }

  /// Réessaie un paiement échoué
  static Future<PaymentResponseDto?> retryPayment(String paymentId, {String? cardId}) async {
    try {
      final Map<String, dynamic> body = cardId != null ? {'card_id': cardId} : <String, dynamic>{};
      final response = await HttpClient.post('/m/payments/$paymentId/retry', body: body);
      
      if (response.isSuccess) {
        return PaymentResponseDto.fromJson(response.json['data']);
      }
      return null;
    } catch (e) {
      debugPrint('[$_tag] Error retrying payment: $e');
      return null;
    }
  }
}

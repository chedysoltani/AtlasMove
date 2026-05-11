import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../core/network/http_client.dart';
import '../models/card_models.dart';

class CardsRepository {
  static const String _tag = 'CardsRepository';

  /// Récupère la liste des cartes du client
  Future<List<CardDto>> getCards() async {
    try {
      final response = await HttpClient.get('/payments/cards');
      if (response.isSuccess) {
        final List<dynamic> data = response.json['data'] as List<dynamic>;
        return data.map((json) => CardDto.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des cartes: ${response.body}');
      }
    } catch (e) {
      debugPrint('[$_tag] Error fetching cards: $e');
      rethrow;
    }
  }

  /// Initialise le flux d'ajout de carte (SetupIntent)
  Future<void> addCard() async {
    try {
      // 1. Demander un SetupIntent au backend
      final response = await HttpClient.post('/payments/cards/setup-intent');
      if (!response.isSuccess) {
        throw Exception('Impossible de créer le SetupIntent: ${response.body}');
      }

      final data = response.json['data'];
      final clientSecret = data['client_secret'];

      // 2. Initialiser le Payment Sheet de Stripe
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'ATLAS',
          style: ThemeMode.system,
        ),
      );

      // 3. Présenter le Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Récupérer le PaymentMethod ID après confirmation
      final result = await Stripe.instance.retrieveSetupIntent(clientSecret);
      final pmId = result.paymentMethodId;

      if (pmId == null) {
        throw Exception('PaymentMethod ID non trouvé après succès');
      }

      // 5. Synchroniser avec le backend
      final syncResponse = await HttpClient.post('/payments/cards/sync', body: {
        'stripe_payment_method_id': pmId,
      });

      if (!syncResponse.isSuccess) {
        throw Exception('Erreur lors de la synchronisation de la carte: ${syncResponse.body}');
      }
    } on StripeException catch (e) {
      if (e.error.localizedMessage?.contains('cancelled') ?? false) {
        // Annulation par l'utilisateur, pas d'erreur à lever
        return;
      }
      rethrow;
    } catch (e) {
      debugPrint('[$_tag] Error adding card: $e');
      rethrow;
    }
  }

  /// Définit une carte comme carte par défaut
  Future<List<CardDto>> setDefault(String cardId) async {
    try {
      final response = await HttpClient.patch('/payments/cards/$cardId/default');
      if (response.isSuccess) {
        final List<dynamic> data = response.json['data'] as List<dynamic>;
        return data.map((json) => CardDto.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la mise à jour de la carte par défaut');
      }
    } catch (e) {
      debugPrint('[$_tag] Error setting default card: $e');
      rethrow;
    }
  }

  /// Supprime une carte
  Future<void> removeCard(String cardId) async {
    try {
      final response = await HttpClient.delete('/payments/cards/$cardId');
      if (!response.isSuccess) {
        throw Exception('Erreur lors de la suppression de la carte');
      }
    } catch (e) {
      debugPrint('[$_tag] Error removing card: $e');
      rethrow;
    }
  }
}

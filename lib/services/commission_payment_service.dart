import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../models/commission_models.dart';

class CommissionPaymentService {
  static Future<CommissionPaymentInfo?> fetchPaymentInfo(
    String month, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final params = <String, String>{'month': month};
      if (latitude != null) params['latitude'] = latitude.toStringAsFixed(6);
      if (longitude != null) params['longitude'] = longitude.toStringAsFixed(6);

      final response = await HttpClient.get(
        '/m/rendezvous/commission/payment-info',
        queryParams: params,
      );
      debugPrint('💳 payment-info status=${response.statusCode} body=${response.json}');
      if (!response.isSuccess) return null;

      final raw = response.json;
      // Handle double-nested: { data: { message, data: {...} } }
      Map<String, dynamic> data;
      final outer = raw['data'];
      if (outer is Map<String, dynamic>) {
        final inner = outer['data'];
        data = (inner is Map<String, dynamic>) ? inner : outer;
      } else {
        data = raw;
      }
      debugPrint('💳 payment-info parsed: $data');
      return CommissionPaymentInfo.fromJson(data);
    } catch (e) {
      debugPrint('⚠️ fetchPaymentInfo: $e');
      return null;
    }
  }

  static Future<List<CommissionPaymentRecord>> fetchPaymentHistory() async {
    try {
      final response = await HttpClient.get('/m/rendezvous/commission/payments');
      debugPrint('💳 payments history status=${response.statusCode}');
      if (!response.isSuccess) return [];

      final raw = response.json;
      // Handle double-nested: { data: { message, data: [...] } }
      List list = [];
      final outer = raw['data'];
      if (outer is List) {
        list = outer;
      } else if (outer is Map<String, dynamic>) {
        final inner = outer['data'];
        list = (inner is List) ? inner : [];
      }
      return list
          .map((j) => CommissionPaymentRecord.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ fetchPaymentHistory: $e');
      return [];
    }
  }

  static Future<String> submitPayment({
    required String month,
    required String transactionHash,
    required double amount,
    required String currency,
  }) async {
    final response = await HttpClient.post(
      '/m/rendezvous/commission/submit-payment',
      body: {
        'month': month,
        'transaction_hash': transactionHash,
        'amount': amount,
        'currency': currency,
      },
    );
    debugPrint('💳 submit-payment status=${response.statusCode} body=${response.json}');
    if (response.isSuccess) {
      return response.json['data']?['status']?.toString() ?? 'pending_verification';
    }
    final msg = response.json['message']?.toString() ?? 'Erreur lors de la soumission';
    throw Exception(msg);
  }
}

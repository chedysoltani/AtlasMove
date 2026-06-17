import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../models/driver_subscription_models.dart';

// ── Manual USDT payment service (hash submission flow) ─────────────────────

class SubscriptionPaymentService {
  static Future<SubscriptionPaymentInfo?> fetchPaymentInfo({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final params = <String, String>{};
      if (latitude != null) params['latitude'] = latitude.toStringAsFixed(6);
      if (longitude != null) params['longitude'] = longitude.toStringAsFixed(6);

      final query = params.isNotEmpty
          ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
          : '';
      final response = await HttpClient.get('/m/livreur/subscription/payment-info$query');
      debugPrint('💳 sub payment-info status=${response.statusCode}');
      if (!response.isSuccess) return null;

      final raw = response.json;
      Map<String, dynamic> data;
      final outer = raw['data'];
      if (outer is Map<String, dynamic>) {
        final inner = outer['data'];
        data = (inner is Map<String, dynamic>) ? inner : outer;
      } else {
        data = raw;
      }
      debugPrint('💳 sub payment-info parsed: $data');
      return SubscriptionPaymentInfo.fromJson(data);
    } catch (e) {
      debugPrint('⚠️ fetchSubscriptionPaymentInfo: $e');
      return null;
    }
  }

  static Future<List<SubscriptionPaymentRecord>> fetchPaymentHistory() async {
    try {
      final response = await HttpClient.get('/m/livreur/subscription/payment-history');
      debugPrint('💳 sub payment-history status=${response.statusCode}');
      if (!response.isSuccess) return [];

      // Le backend peut retourner un tableau JSON direct ou enveloppé dans data
      final decoded = jsonDecode(response.body);
      List list = [];
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        final outer = decoded['data'];
        if (outer is List) {
          list = outer;
        } else if (outer is Map) {
          final inner = outer['data'];
          list = (inner is List) ? inner : [];
        }
      }
      return list
          .map((j) => SubscriptionPaymentRecord.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ fetchSubscriptionPaymentHistory: $e');
      return [];
    }
  }

  static Future<void> submitPayment({
    required String transactionHash,
    required double amount,
    required String currency,
  }) async {
    final response = await HttpClient.post(
      '/m/livreur/subscription/submit-payment',
      body: {
        'transaction_hash': transactionHash,
        'amount': amount,
        'currency': currency,
      },
    );
    debugPrint('💳 sub submit-payment status=${response.statusCode} body=${response.json}');
    if (!response.isSuccess) {
      final msg = response.json['message']?.toString() ??
          response.json['data']?['message']?.toString() ??
          'Erreur lors de la soumission';
      throw Exception(msg);
    }
  }
}

class PrivilegeService {
  static Future<PrivilegeDashboard> getDashboard() async {
    final response = await HttpClient.get('/m/livreur/subscription/dashboard');
    final json = response.json;
    // Double-nested: { data: { message, data: { vip_level, ... } } }
    final outer = (json['data'] as Map<String, dynamic>?) ?? json;
    final data = (outer['data'] as Map<String, dynamic>?) ?? outer;
    return PrivilegeDashboard.fromJson(data);
  }
}

class ClientLoyaltyService {
  static Future<ClientLoyaltyStatus> getStatus() async {
    final response = await HttpClient.get('/m/client/loyalty/status');
    final json = response.json;
    // Possibly wrapped: { data: { active_programs: [...] } }
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return ClientLoyaltyStatus.fromJson(data);
  }
}

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  DriverSubscriptionStatus? _status;
  bool _isLoading = false;
  String? _error;

  DriverSubscriptionStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasActiveSubscription => _status?.hasActiveSubscription ?? false;
  DriverSubscription? get subscription => _status?.subscription;
  LoyaltyProgram? get loyaltyProgram => _status?.loyaltyProgram;

  // Legacy compatibility getters used by existing screens
  bool get isSubscriptionValid => hasActiveSubscription;
  bool get isSubscribed => subscription?.isActive ?? false;
  bool get isTrialActive => subscription?.isTrial ?? false;
  bool get hasUsedTrial => subscription != null;
  DateTime? get expiryDate => subscription?.expiresAt;

  Future<void> fetchStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await HttpClient.get('/m/livreur/subscription/status');
      _status = DriverSubscriptionStatus.fromJson(response.json);
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ SubscriptionService fetchStatus: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> subscribe({String currency = 'USD'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await HttpClient.post(
        '/m/livreur/subscription/subscribe',
        body: {'currency': currency},
      );
      await fetchStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Legacy method kept for crypto recharge screen compatibility.
  /// Refreshes subscription status after a crypto payment confirmation.
  Future<bool> confirmCryptoPayment(dynamic asset, String txHash) async {
    await fetchStatus();
    return hasActiveSubscription;
  }

  Future<CryptoSubscriptionSession> initiateSession({double amount = 90.0}) async {
    final response = await HttpClient.post(
      '/m/livreur/subscription/initiate',
      body: {'amount': amount},
    );
    return CryptoSubscriptionSession.fromJson(response.json);
  }

  Future<CryptoSubscriptionSession> pollSession(String sessionId) async {
    final response = await HttpClient.get('/m/livreur/subscription/session/$sessionId');
    return CryptoSubscriptionSession.fromJson(response.json);
  }

  Future<bool> cancelRenewal() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await HttpClient.post('/m/livreur/subscription/cancel');
      await fetchStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

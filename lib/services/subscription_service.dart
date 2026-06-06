import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../models/driver_subscription_models.dart';

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

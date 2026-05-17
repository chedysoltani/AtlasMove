import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crypto_asset_model.dart';

class SubscriptionService extends ChangeNotifier {
  // Singleton Pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal() {
    _loadSubscriptionState();
  }

  bool _isSubscribed = false;
  bool _isTrialActive = false;
  bool _hasUsedTrial = false;
  DateTime? _expiryDate;
  bool _isLoading = false;

  // Getters
  bool get isSubscribed => _isSubscribed;
  bool get isTrialActive => _isTrialActive;
  bool get hasUsedTrial => _hasUsedTrial;
  DateTime? get expiryDate => _expiryDate;
  bool get isLoading => _isLoading;

  // Check subscription validity
  bool get isSubscriptionValid {
    if (_isSubscribed || _isTrialActive) {
      if (_expiryDate != null) {
        return _expiryDate!.isAfter(DateTime.now());
      }
    }
    return false;
  }

  // Load state from SharedPreferences
  Future<void> _loadSubscriptionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSubscribed = prefs.getBool('driver_sub_active') ?? false;
      _isTrialActive = prefs.getBool('driver_trial_active') ?? false;
      _hasUsedTrial = prefs.getBool('driver_has_used_trial') ?? false;
      
      final expiryStr = prefs.getString('driver_sub_expiry');
      if (expiryStr != null) {
        _expiryDate = DateTime.parse(expiryStr);
        // Autovalider si expiré
        if (_expiryDate!.isBefore(DateTime.now())) {
          _isSubscribed = false;
          _isTrialActive = false;
          await prefs.setBool('driver_sub_active', false);
          await prefs.setBool('driver_trial_active', false);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ SubscriptionService: Erreur de chargement: $e');
    }
  }

  // Activer le 1er mois d'essai gratuit
  Future<bool> activateFreeTrial() async {
    if (_hasUsedTrial) return false;
    _isLoading = true;
    notifyListeners();

    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 1500));

      final prefs = await SharedPreferences.getInstance();
      _isTrialActive = true;
      _hasUsedTrial = true;
      _expiryDate = DateTime.now().add(const Duration(days: 30));

      await prefs.setBool('driver_trial_active', true);
      await prefs.setBool('driver_has_used_trial', true);
      await prefs.setString('driver_sub_expiry', _expiryDate!.toIso8601String());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Simuler et confirmer le paiement par cryptomonnaie
  Future<bool> confirmCryptoPayment(CryptoAsset asset, String txHash) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simuler la validation par la blockchain (3 secondes pour de la crédibilité)
      await Future.delayed(const Duration(seconds: 3));

      final prefs = await SharedPreferences.getInstance();
      _isSubscribed = true;
      _isTrialActive = false; // Désactive l'essai car abonné payant
      
      // Ajouter 30 jours à la date actuelle ou à la date d'expiration restante si valide
      DateTime baseDate = DateTime.now();
      if (_expiryDate != null && _expiryDate!.isAfter(DateTime.now())) {
        baseDate = _expiryDate!;
      }
      _expiryDate = baseDate.add(const Duration(days: 30));

      await prefs.setBool('driver_sub_active', true);
      await prefs.setBool('driver_trial_active', false);
      await prefs.setString('driver_sub_expiry', _expiryDate!.toIso8601String());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Réinitialiser l'abonnement (pour les tests développeurs)
  Future<void> resetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    _isSubscribed = false;
    _isTrialActive = false;
    _hasUsedTrial = false;
    _expiryDate = null;
    
    await prefs.remove('driver_sub_active');
    await prefs.remove('driver_trial_active');
    await prefs.remove('driver_has_used_trial');
    await prefs.remove('driver_sub_expiry');
    notifyListeners();
  }
}

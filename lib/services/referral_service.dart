import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../models/referral_models.dart';

class ReferralService extends ChangeNotifier {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  ReferralData? _data;
  bool _isLoading = false;
  String? _error;

  ReferralData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchReferrals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await HttpClient.get('/users/profile/referrals');
      _data = ReferralData.fromJson(response.json);
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ ReferralService fetchReferrals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

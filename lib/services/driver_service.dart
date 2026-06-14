import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import 'profile_service.dart';

class DriverService {
  DriverService._();

  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(false);

  static bool get isOnline => isOnlineNotifier.value;

  /// Loads the real availability status from the profile API.
  static Future<void> loadAvailability() async {
    try {
      final resp = await ProfileService.getCurrentProfile();
      isOnlineNotifier.value = resp.user.isAvailable;
    } catch (e) {
      debugPrint('⚠️ DriverService: could not load availability: $e');
    }
  }

  /// PATCH /users/availability  { "isAvailable": bool }
  static Future<void> setAvailability(bool available) async {
    final response = await HttpClient.patch(
      '/users/availability',
      body: {'isAvailable': available},
    );
    if (!response.isSuccess) {
      throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
    }
    isOnlineNotifier.value = available;
  }

  static Future<Map<String, dynamic>?> fetchDailyStats({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final params = <String, String>{};
      if (latitude != null) params['latitude'] = latitude.toStringAsFixed(6);
      if (longitude != null) params['longitude'] = longitude.toStringAsFixed(6);
      final response = await HttpClient.get(
        '/m/driver/stats',
        queryParams: params.isEmpty ? null : params,
      );
      debugPrint('📊 driver/stats raw: ${response.json}');
      if (response.isSuccess) {
        final raw = response.json;
        final data = (raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;
        debugPrint('📊 driver/stats parsed data: $data');
        return {
          'today_earnings': double.tryParse(data['today_earnings']?.toString() ?? '0') ?? 0.0,
          'today_rides': int.tryParse(data['today_rides']?.toString() ?? '0') ?? 0,
          'currency': data['currency']?.toString() ?? 'TND',
        };
      }
    } catch (e) {
      debugPrint('⚠️ DriverService.fetchDailyStats: $e');
    }
    return null;
  }
}

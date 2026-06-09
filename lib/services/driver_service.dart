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
}

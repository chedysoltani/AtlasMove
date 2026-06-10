import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';

class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Déclenche une alerte SOS.
  /// Spec : POST /sos/trigger  { trip_id?, latitude, longitude }
  /// Rate-limit backend : 3 déclenchements max par heure.
  Future<bool> trigger({
    String? tripId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final body = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (tripId != null) 'trip_id': tripId,
      };

      final response = await HttpClient.post('/sos/trigger', body: body);

      if (response.isSuccess) {
        debugPrint('🆘 SosService: alerte déclenchée avec succès');
        return true;
      }

      // 429 = rate limit (3/heure dépassé)
      if (response.statusCode == 429) {
        debugPrint('⚠️ SosService: limite d\'alertes atteinte (3/heure)');
      } else {
        debugPrint('❌ SosService: erreur ${response.statusCode}');
      }

      return false;
    } catch (e) {
      debugPrint('💥 SosService: $e');
      return false;
    }
  }
}

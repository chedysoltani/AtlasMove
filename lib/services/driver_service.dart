import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';

class DriverService {
  DriverService._();

  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(false);

  static bool get isOnline => isOnlineNotifier.value;

  /// Recharge la disponibilité depuis le serveur, si l'API la renvoie.
  ///
  /// `GET /users/profile` NE renvoie PAS `is_available` (confirmé le 2026-09-30 :
  /// ni sur `data.user`, ni sur `data.user.external_user` — seulement `is_active`,
  /// `status` et `livreur_status`, qui sont d'autres notions). `User.fromMap`
  /// retombe donc toujours sur `false` en son absence. Avant, on écrasait
  /// systématiquement l'état en mémoire avec ce `false` fabriqué à chaque
  /// rechargement du dashboard (ex. juste après une course) — le chauffeur restait
  /// réellement en ligne côté serveur, l'app affichait "hors ligne" par erreur.
  ///
  /// Tant que le backend n'expose pas ce champ ici, on ne touche à l'état
  /// affiché QUE si la clé est vraiment présente dans la réponse ; sinon on
  /// conserve la dernière valeur connue (posée par le bouton de bascule, qui
  /// reste la seule source fiable pour l'instant).
  static Future<void> loadAvailability() async {
    try {
      final response = await HttpClient.get('/users/profile');
      if (!response.isSuccess) return;
      final json = response.json;
      final root = json['data'] is Map ? json['data'] as Map : json;
      final user = root['user'] is Map ? root['user'] as Map : root;
      if (user.containsKey('is_available') || user.containsKey('isAvailable')) {
        isOnlineNotifier.value = (user['is_available'] ?? user['isAvailable']) == true;
      } else {
        debugPrint('⚠️ DriverService: is_available absent de /users/profile — état conservé');
      }
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

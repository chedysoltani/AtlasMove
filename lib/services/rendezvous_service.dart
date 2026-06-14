import 'package:flutter/foundation.dart';
import '../core/network/http_client.dart';
import '../models/rendezvous_models.dart';

class RendezvousService {
  // ─── Client endpoints ────────────────────────────────────────────────────────

  static Future<Rendezvous> bookRendezvous({
    required String serviceId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? details,
    required String address,
    required double latitude,
    required double longitude,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? cargoDescription,
    double? cargoWeightKg,
    String? cargoSize,
    bool? isFragile,
    double? estimatedFare,
    double? estimatedDistanceKm,
    String? currency,
  }) async {
    debugPrint('=== RendezvousService.bookRendezvous() START ===');
    try {
      final body = <String, dynamic>{
        'service_id': serviceId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (details != null && details.isNotEmpty) 'details': details,
        if (destinationAddress != null && destinationAddress.isNotEmpty)
          'destination_address': destinationAddress,
        if (destinationLatitude != null) 'destination_latitude': destinationLatitude,
        if (destinationLongitude != null) 'destination_longitude': destinationLongitude,
        if (cargoDescription != null && cargoDescription.isNotEmpty)
          'cargo_description': cargoDescription,
        if (cargoWeightKg != null) 'cargo_weight_kg': cargoWeightKg,
        if (cargoSize != null) 'cargo_size': cargoSize,
        if (isFragile != null) 'is_fragile': isFragile,
        if (estimatedFare != null) 'estimated_fare': estimatedFare,
        if (estimatedDistanceKm != null) 'estimated_distance_km': estimatedDistanceKm,
        if (currency != null) 'currency': currency,
      };
      debugPrint('Body: $body');
      final response = await HttpClient.post('/m/rendezvous', body: body);
      if (response.isSuccess) {
        final json = response.json;
        final outer = json['data'];
        Map<String, dynamic> rdvJson = {};
        if (outer is Map<String, dynamic>) {
          final inner = outer['data'];
          rdvJson = (inner is Map<String, dynamic>) ? inner : outer;
        }
        return Rendezvous.fromJson(rdvJson);
      } else {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur lors de la réservation',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR bookRendezvous: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    } finally {
      debugPrint('=== RendezvousService.bookRendezvous() END ===');
    }
  }

  static Future<RendezvousListResponse> getClientHistory({
    int page = 1,
    int limit = 10,
  }) async {
    debugPrint('=== RendezvousService.getClientHistory() page=$page ===');
    try {
      final response = await HttpClient.get(
        '/m/rendezvous/history/client',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );
      if (response.isSuccess) {
        return RendezvousListResponse.fromJson(response.json);
      } else {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur chargement historique',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR getClientHistory: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> cancelRendezvous(String id) async {
    debugPrint('=== RendezvousService.cancelRendezvous() id=$id ===');
    try {
      final response = await HttpClient.patch('/m/rendezvous/$id/cancel');
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur annulation',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR cancelRendezvous: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  // ─── Driver endpoints ────────────────────────────────────────────────────────

  static Future<RendezvousListResponse> getDriverHistory({
    int page = 1,
    int limit = 10,
  }) async {
    debugPrint('=== RendezvousService.getDriverHistory() page=$page ===');
    try {
      final response = await HttpClient.get(
        '/m/rendezvous/history/livreur',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );
      if (response.isSuccess) {
        return RendezvousListResponse.fromJson(response.json);
      } else {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur chargement historique',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR getDriverHistory: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<RendezvousListResponse> getAvailableBookings({
    int page = 1,
    int limit = 10,
  }) async {
    debugPrint('=== RendezvousService.getAvailableBookings() page=$page ===');
    try {
      final response = await HttpClient.get(
        '/m/rendezvous/available',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
      );
      if (response.isSuccess) {
        return RendezvousListResponse.fromJson(response.json);
      } else {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur chargement disponibles',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR getAvailableBookings: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<List<Rendezvous>> getDriverSchedule({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('=== RendezvousService.getDriverSchedule() ===');
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final response = await HttpClient.get(
        '/m/rendezvous/schedule',
        queryParams: {
          'startDate': start.toUtc().toIso8601String(),
          'endDate': end.toUtc().toIso8601String(),
        },
      );
      if (response.isSuccess) {
        // Schedule may return a flat list or paginated
        final json = response.json;
        List<dynamic> rawList = [];
        final outer = json['data'];
        if (outer is List) {
          rawList = outer;
        } else if (outer is Map<String, dynamic>) {
          final inner = outer['data'];
          if (inner is List) {
            rawList = inner;
          } else if (inner is Map<String, dynamic>) {
            rawList = inner['data'] as List? ?? [];
          }
        }
        return rawList
            .map((j) => Rendezvous.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur chargement planning',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR getDriverSchedule: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> acceptBooking(
    String id, {
    double? finalFare,
    String? currency,
  }) async {
    debugPrint('=== RendezvousService.acceptBooking() id=$id fare=$finalFare ===');
    try {
      final body = <String, dynamic>{
        if (finalFare != null) 'final_fare': finalFare,
        if (currency != null) 'currency': currency,
      };
      final response = await HttpClient.patch(
        '/m/rendezvous/$id/accept',
        body: body.isNotEmpty ? body : null,
      );
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur acceptation',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR acceptBooking: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> proposeOffer(String rdvId, double proposedFare, {String currency = 'TND'}) async {
    debugPrint('=== RendezvousService.proposeOffer() id=$rdvId fare=$proposedFare currency=$currency ===');
    try {
      final response = await HttpClient.post(
        '/m/rendezvous/$rdvId/offers',
        body: {'proposed_fare': proposedFare, 'currency': currency},
      );
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur proposition',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR proposeOffer: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> rejectBooking(String id) async {
    debugPrint('=== RendezvousService.rejectBooking() id=$id ===');
    try {
      final response = await HttpClient.patch('/m/rendezvous/$id/reject');
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur libération',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR rejectBooking: $e');
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  // ─── Estimation ──────────────────────────────────────────────────────────

  static Future<RendezvousEstimate?> estimateRendezvous({
    required String serviceId,
    required double distanceKm,
    required double durationMinutes,
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('=== RendezvousService.estimateRendezvous() ===');
    try {
      final response = await HttpClient.post('/m/rendezvous/estimate', body: {
        'service_id': serviceId,
        'distance_km': double.parse(distanceKm.toStringAsFixed(2)),
        'duration_minutes': durationMinutes.round(),
        'latitude': double.parse(latitude.toStringAsFixed(6)),
        'longitude': double.parse(longitude.toStringAsFixed(6)),
      });
      if (response.isSuccess) {
        final outer = response.json['data'];
        if (outer is Map<String, dynamic>) {
          // Handle nested { message, data: {...} } wrapper
          final inner = outer['data'] ?? outer;
          if (inner is Map<String, dynamic>) {
            return RendezvousEstimate.fromJson(inner);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('ERREUR estimateRendezvous: $e');
      return null;
    }
  }

  // ─── Offers / Negotiation ─────────────────────────────────────────────────

  static Future<List<RendezvousOffer>> getOffers(String rdvId) async {
    debugPrint('=== RendezvousService.getOffers() id=$rdvId ===');
    try {
      final response = await HttpClient.get('/m/rendezvous/$rdvId/offers');
      if (response.isSuccess) {
        final raw = _extractList(response.json);
        return raw.map((j) => RendezvousOffer.fromJson(j as Map<String, dynamic>)).toList();
      }
      throw RendezvousException(
        message: response.json['message'] ?? 'Erreur chargement offres',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> acceptOffer(String offerId) async {
    debugPrint('=== RendezvousService.acceptOffer() id=$offerId ===');
    try {
      final response = await HttpClient.post('/m/rendezvous/offers/$offerId/accept');
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur acceptation offre',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> rejectOffer(String offerId) async {
    debugPrint('=== RendezvousService.rejectOffer() id=$offerId ===');
    try {
      final response = await HttpClient.post('/m/rendezvous/offers/$offerId/reject');
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur rejet offre',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static Future<void> counterOffer(String offerId, double proposedFare, {String currency = 'TND'}) async {
    debugPrint('=== RendezvousService.counterOffer() id=$offerId fare=$proposedFare currency=$currency ===');
    try {
      final response = await HttpClient.post(
        '/m/rendezvous/offers/$offerId/counter',
        body: {'proposed_fare': proposedFare, 'currency': currency},
      );
      if (!response.isSuccess) {
        throw RendezvousException(
          message: response.json['message'] ?? 'Erreur contre-offre',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is RendezvousException) rethrow;
      throw RendezvousException(message: e.toString());
    }
  }

  static List<dynamic> _extractList(Map<String, dynamic> json) {
    final outer = json['data'];
    if (outer is List) return outer;
    if (outer is Map<String, dynamic>) {
      final inner = outer['data'];
      if (inner is List) return inner;
    }
    return [];
  }
}

class RendezvousException implements Exception {
  final String message;
  final int? statusCode;

  const RendezvousException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

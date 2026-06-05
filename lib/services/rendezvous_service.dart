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
  }) async {
    debugPrint('=== RendezvousService.bookRendezvous() START ===');
    try {
      final body = {
        'service_id': serviceId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (details != null && details.isNotEmpty) 'details': details,
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

  static Future<void> acceptBooking(String id) async {
    debugPrint('=== RendezvousService.acceptBooking() id=$id ===');
    try {
      final response = await HttpClient.patch('/m/rendezvous/$id/accept');
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
}

class RendezvousException implements Exception {
  final String message;
  final int? statusCode;

  const RendezvousException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

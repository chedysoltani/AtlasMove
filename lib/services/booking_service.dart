import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingService {
  static const String baseUrl = 'https://api.atla.business/api/v1';

  static Future<List<Map<String, dynamic>>> getTruckSizes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/truck-sizes'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['truck_sizes'] ?? []);
      } else {
        throw Exception('Failed to load truck sizes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching truck sizes: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> calculateEstimate({
    required String departure,
    required String destination,
    required String serviceType,
    int? passengers,
    double? weight,
    String? truckSize,
    bool? isFragile,
    bool? needHelp,
  }) async {
    try {
      final requestBody = {
        'departure': departure,
        'destination': destination,
        'service_type': serviceType,
        if (passengers != null) 'passengers': passengers,
        if (weight != null) 'weight_kg': weight,
        if (truckSize != null) 'truck_size': truckSize,
        if (isFragile != null) 'is_fragile': isFragile,
        if (needHelp != null) 'need_loading_help': needHelp,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trips/estimate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'price': data['price'] ?? 0.0,
          'distance': data['distance'] ?? 0.0,
          'estimated_time': data['estimated_time'] ?? 0,
          'currency': data['currency'] ?? 'MAD',
        };
      } else {
        throw Exception('Failed to calculate estimate: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating estimate: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createTrip({
    required String token,
    required String departure,
    required String destination,
    required String category,
    required String serviceType,
    DateTime? scheduledTime,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final requestBody = {
        'departure': departure,
        'destination': destination,
        'category': category,
        'service_type': serviceType,
        'scheduled_time': scheduledTime?.toIso8601String(),
        ...?additionalData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trips/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create trip: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating trip: $e');
      rethrow;
    }
  }
}

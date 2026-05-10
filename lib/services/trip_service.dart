import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/trip_models.dart';
import '../core/network/http_client.dart';

class TripService {
  
  static Future<TripResponse> createTrip({
    required String serviceId,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required double estimatedDistanceKm,
    required int estimatedDurationMin,
  }) async {
    // LOG: Début de la fonction
    debugPrint('=== TripService.createTrip() START ===');
    
    try {
      // LOG: Préparation des données
      final requestData = {
        'service_id': serviceId,
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'destination_address': destinationAddress,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
        'estimated_distance_km': double.parse(estimatedDistanceKm.toStringAsFixed(2)), // 2 décimales max
        'estimated_duration_min': estimatedDurationMin,
      };
      
      debugPrint('Données envoyées: $requestData');
      
      // Utiliser HttpClient avec authentification automatique
      final response = await HttpClient.post('/m/trips', body: requestData);

      // LOG: Réponse reçue
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      if (response.isSuccess) {
        try {
          final responseData = response.json;
          debugPrint('JSON décodé avec succès: $responseData');
          
          final tripResponse = TripResponse.fromJson(responseData);
          debugPrint('TripResponse créé: ${tripResponse.toString()}');
          
          return tripResponse;
        } catch (parseError) {
          debugPrint('ERREUR parsing JSON: $parseError');
          debugPrint('Body qui a causé l\'erreur: ${response.body}');
          throw TripException(
            message: 'Invalid JSON response: ${parseError.toString()}',
            statusCode: response.statusCode,
          );
        }
      } else {
        debugPrint('ERREUR HTTP: ${response.statusCode}');
        debugPrint('Body d\'erreur: ${response.body}');
        
        throw TripException(
          message: response.json['message'] ?? 'Failed to create trip',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR CATCH: $e');
      debugPrint('Type d\'erreur: ${e.runtimeType}');
      
      // Convertir les autres exceptions en TripException
      throw TripException(
        message: e.toString(),
        statusCode: null,
      );
    } finally {
      debugPrint('=== TripService.createTrip() END ===');
    }
  }

  static Future<List<AvailableTrip>> getAvailableTrips({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
  }) async {
    debugPrint('=== TripService.getAvailableTrips() START ===');
    debugPrint('Params: lat=$latitude, lng=$longitude, radius=$radiusKm');
    
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
      };
      
      final response = await HttpClient.get('/l/trips/available', queryParams: queryParams);
      
      debugPrint('Status Code: ${response.statusCode}');
      
      if (response.isSuccess) {
        // Le backend renvoie probablement le tableau directement ou dans un objet "data"
        List<dynamic> tripsJson = [];
        
        try {
          final jsonBody = response.json;
          // Handle format: {"data": {"message": "...", "data": [...]}}
          if (jsonBody.containsKey('data')) {
            final innerData = jsonBody['data'];
            if (innerData is Map && innerData.containsKey('data') && innerData['data'] is List) {
              tripsJson = innerData['data'] as List;
            } else if (innerData is List) {
              tripsJson = innerData;
            } else {
              debugPrint('Format de réponse inattendu: data n\'est ni une liste ni un objet contenant une liste');
            }
          }
        } catch (e) {
          final rawJson = jsonDecode(response.body);
          if (rawJson is List) {
            tripsJson = rawJson;
          }
        }
        
        debugPrint('Nombre de courses trouvées: ${tripsJson.length}');
        
        final trips = tripsJson
            .map((json) => AvailableTrip.fromJson(json as Map<String, dynamic>))
            .toList();
            
        return trips;
      } else {
        throw TripException(
          message: 'Failed to fetch available trips',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR fetching available trips: $e');
      throw TripException(
        message: e.toString(),
        statusCode: null,
      );
    } finally {
      debugPrint('=== TripService.getAvailableTrips() END ===');
    }
  }
  static Future<void> acceptTrip(String tripId) async {
    debugPrint('=== TripService.acceptTrip() START ===');
    debugPrint('Trip ID: $tripId');

    try {
      final response = await HttpClient.patch('/l/trips/$tripId/accept');

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (response.isSuccess) {
        debugPrint('✅ Trip accepted successfully');
      } else {
        debugPrint('❌ Failed to accept trip. Status: ${response.statusCode}');
        throw Exception('Failed to accept trip: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'acceptation de la course: $e');
      throw Exception('Erreur de connexion lors de l\'acceptation');
    } finally {
      debugPrint('=== TripService.acceptTrip() END ===');
    }
  }
}

class TripException implements Exception {
  final String message;
  final int? statusCode;
  
  TripException({required this.message, this.statusCode});
  
  @override
  String toString() => message;
}

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
}

class TripException implements Exception {
  final String message;
  final int? statusCode;
  
  TripException({required this.message, this.statusCode});
  
  @override
  String toString() => message;
}

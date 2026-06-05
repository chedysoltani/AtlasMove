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
    required String paymentType, // "card" | "cash"
    bool isNegotiable = true,
    double? offeredFare,
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
        'payment_type': paymentType,
        'is_negotiable': isNegotiable,
        if (offeredFare != null) 'offered_fare': offeredFare,
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
  static Future<AvailableTrip?> getActiveTrip() async {
    debugPrint('=== TripService.getActiveTrip() START ===');
    try {
      final response = await HttpClient.get('/l/trips/active');
      
      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (response.isSuccess) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // L'API renvoie: { "data": { "message": "...", "data": { ...trip... } } }
        // Il faut donc désimbriquer deux fois
        final outer = responseData['data'];
        if (outer == null) return null;

        // Cas 1 : format { message, data: {...trip...} }
        if (outer is Map<String, dynamic> && outer.containsKey('data') && outer['data'] is Map) {
          final tripJson = outer['data'] as Map<String, dynamic>;
          debugPrint('✅ Trip parsé depuis data.data: id=${tripJson['id']}');
          return AvailableTrip.fromJson(tripJson);
        }

        // Cas 2 : format direct { ...trip... }
        if (outer is Map<String, dynamic> && outer.containsKey('id')) {
          debugPrint('✅ Trip parsé depuis data directement: id=${outer['id']}');
          return AvailableTrip.fromJson(outer);
        }

        debugPrint('⚠️ Structure de réponse inattendue: $outer');
        return null;
      } else if (response.statusCode == 404) {
        // Pas de course active
        debugPrint('ℹ️ Aucune course active (404)');
        return null;
      } else {
        debugPrint('❌ Failed to get active trip. Status: ${response.statusCode}');
        throw Exception('Failed to fetch active trip');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de la course active: $e');
      return null;
    } finally {
      debugPrint('=== TripService.getActiveTrip() END ===');
    }
  }

  static Future<List<AvailableTrip>> getDriverTrips({int page = 1, int limit = 1}) async {
    debugPrint('=== TripService.getDriverTrips() START ===');
    debugPrint('Params: page=$page, limit=$limit');
    
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      final response = await HttpClient.get('/l/trips', queryParams: queryParams);
      
      debugPrint('Status Code: ${response.statusCode}');
      
      if (response.isSuccess) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> tripsJson = [];
        
        if (decoded is Map) {
          if (decoded['data'] != null) {
            final data = decoded['data'];
            if (data is Map && data['data'] is List) {
              tripsJson = data['data'];
            } else if (data is List) {
              tripsJson = data;
            }
          } else if (decoded['trips'] is List) {
            tripsJson = decoded['trips'];
          }
        } else if (decoded is List) {
          tripsJson = decoded;
        }
        
        debugPrint('getDriverTrips parsed JSON list of length: ${tripsJson.length}');
        return tripsJson.map((json) => AvailableTrip.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw TripException(
          message: response.json['message'] ?? 'Failed to fetch driver trips',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR fetching driver trips: $e');
      throw TripException(
        message: e.toString(),
        statusCode: null,
      );
    } finally {
      debugPrint('=== TripService.getDriverTrips() END ===');
    }
  }


  static Future<void> updateTripStatus(String tripId, String status) async {
    debugPrint('=== TripService.updateTripStatus() START ===');
    debugPrint('Trip ID: $tripId, Status: $status');

    try {
      final response = await HttpClient.patch(
        '/l/trips/$tripId/status',
        body: {'status': status},
      );

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to update trip status. Status: ${response.statusCode}');
        throw Exception('Failed to update trip status');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour du statut: $e');
      throw Exception('Erreur de connexion lors de la mise à jour du statut');
    } finally {
      debugPrint('=== TripService.updateTripStatus() END ===');
    }
  }

  static Future<void> cancelTrip(String tripId, String reason) async {
    debugPrint('=== TripService.cancelTrip() START ===');
    debugPrint('Trip ID: $tripId, Reason: $reason');

    try {
      final response = await HttpClient.patch(
        '/l/trips/$tripId/cancel',
        body: {'reason': reason},
      );

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to cancel trip. Status: ${response.statusCode}');
        throw Exception('Failed to cancel trip');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'annulation de la course: $e');
      throw Exception('Erreur de connexion lors de l\'annulation');
    } finally {
      debugPrint('=== TripService.cancelTrip() END ===');
    }
  }

  static Future<void> cancelClientTrip(String tripId, String reason) async {
    debugPrint('=== TripService.cancelClientTrip() START ===');
    debugPrint('Trip ID: $tripId, Reason: $reason');

    try {
      // Pour les clients, l'endpoint est sous le préfixe /m/trips
      final response = await HttpClient.patch(
        '/m/trips/$tripId/cancel',
        body: {'reason': reason},
      );

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        // En cas d'échec sur /m/ (par exemple si l'API n'est pas encore migrée ou utilise un autre pattern),
        // on tente un fallback vers /l/ pour assurer la continuité de service.
        debugPrint('⚠️ Échec sur /m/trips, essai du fallback sur /l/trips...');
        final fallbackResponse = await HttpClient.patch(
          '/l/trips/$tripId/cancel',
          body: {'reason': reason},
        );
        
        if (!fallbackResponse.isSuccess) {
          debugPrint('❌ Failed to cancel trip with fallback. Status: ${fallbackResponse.statusCode}');
          throw Exception('Failed to cancel trip');
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'annulation de la course par le client: $e');
      throw Exception('Erreur de connexion lors de l\'annulation');
    } finally {
      debugPrint('=== TripService.cancelClientTrip() END ===');
    }
  }

  static Future<ClientDashboardStats> getClientDashboardStats() async {
    debugPrint('=== TripService.getClientDashboardStats() START ===');
    try {
      final response = await HttpClient.get('/m/trips/dashboard/client');
      debugPrint('Dashboard stats status: ${response.statusCode}');
      if (response.isSuccess) {
        final json = response.json;
        final outer = json['data'] as Map<String, dynamic>? ?? json;
        // Réponse imbriquée : { data: { message, data: { totalTrips, ... } } }
        final data = (outer['data'] as Map<String, dynamic>?) ?? outer;
        return ClientDashboardStats(
          totalTrips: int.tryParse(data['totalTrips']?.toString() ?? '0') ?? 0,
          totalSpent: double.tryParse(data['totalSpent']?.toString() ?? '0') ?? 0.0,
          currency: data['currency']?.toString() ?? 'TND',
          upcomingRendezvous:
              int.tryParse(data['upcomingRendezvous']?.toString() ?? '0') ?? 0,
        );
      } else {
        throw Exception('Erreur chargement stats dashboard');
      }
    } catch (e) {
      debugPrint('ERREUR getClientDashboardStats: $e');
      rethrow;
    } finally {
      debugPrint('=== TripService.getClientDashboardStats() END ===');
    }
  }

  static Future<TripHistoryResponse> getClientTripHistory({int page = 1, int limit = 10}) async {
    debugPrint('=== TripService.getClientTripHistory() START ===');
    debugPrint('Params: page=$page, limit=$limit');
    
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      final response = await HttpClient.get('/m/trips', queryParams: queryParams);
      
      debugPrint('Status Code: ${response.statusCode}');
      
      if (response.isSuccess) {
        final jsonBody = response.json;
        return TripHistoryResponse.fromJson(jsonBody);
      } else {
        throw TripException(
          message: response.json['message'] ?? 'Failed to fetch trip history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('ERREUR fetching trip history: $e');
      throw TripException(
        message: e.toString(),
        statusCode: null,
      );
    } finally {
      debugPrint('=== TripService.getClientTripHistory() END ===');
    }
  }

  // --- SYSTÈME DE NÉGOCIATION (BIDDING SYSTEM) ---

  /// Soumettre une offre de prix (Livreur)
  static Future<void> submitDriverOffer(String tripId, double proposedFare) async {
    debugPrint('=== TripService.submitDriverOffer() START ===');
    debugPrint('Trip ID: $tripId, Proposed Fare: $proposedFare');

    try {
      final response = await HttpClient.post(
        '/l/trips/$tripId/offers',
        body: {'proposedFare': proposedFare},
      );

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to submit driver offer. Status: ${response.statusCode}');
        throw Exception(response.json['message'] ?? 'Failed to submit offer');
      }
      debugPrint('✅ Driver offer submitted successfully');
    } catch (e) {
      debugPrint('❌ Erreur lors de la soumission de l\'offre: $e');
      throw Exception(e.toString());
    } finally {
      debugPrint('=== TripService.submitDriverOffer() END ===');
    }
  }

  /// Accepter une offre (Client ou Livreur suite à contre-proposition)
  static Future<void> acceptOffer(String offerId) async {
    debugPrint('=== TripService.acceptOffer() START ===');
    debugPrint('Offer ID: $offerId');

    try {
      final response = await HttpClient.post('/m/trips/offers/$offerId/accept');

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to accept offer. Status: ${response.statusCode}');
        throw Exception(response.json['message'] ?? 'Failed to accept offer');
      }
      debugPrint('✅ Offer accepted successfully');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'acceptation de l\'offre: $e');
      throw Exception(e.toString());
    } finally {
      debugPrint('=== TripService.acceptOffer() END ===');
    }
  }

  /// Proposer un contre-tarif (Client)
  static Future<void> counterOffer(String offerId, double proposedFare) async {
    debugPrint('=== TripService.counterOffer() START ===');
    debugPrint('Offer ID: $offerId, Proposed Fare: $proposedFare');

    try {
      final response = await HttpClient.post(
        '/m/trips/offers/$offerId/counter',
        body: {'proposedFare': proposedFare},
      );

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to counter offer. Status: ${response.statusCode}');
        throw Exception(response.json['message'] ?? 'Failed to propose counter fare');
      }
      debugPrint('✅ Counter offer sent successfully');
    } catch (e) {
      debugPrint('❌ Erreur lors de la contre-proposition: $e');
      throw Exception(e.toString());
    } finally {
      debugPrint('=== TripService.counterOffer() END ===');
    }
  }

  /// Rejeter/Décliner une offre (Client ou Livreur)
  static Future<void> rejectOffer(String offerId) async {
    debugPrint('=== TripService.rejectOffer() START ===');
    debugPrint('Offer ID: $offerId');

    try {
      final response = await HttpClient.post('/m/trips/offers/$offerId/reject');

      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (!response.isSuccess) {
        debugPrint('❌ Failed to reject offer. Status: ${response.statusCode}');
        throw Exception(response.json['message'] ?? 'Failed to reject offer');
      }
      debugPrint('✅ Offer rejected successfully');
    } catch (e) {
      debugPrint('❌ Erreur lors du rejet de l\'offre: $e');
      throw Exception(e.toString());
    } finally {
      debugPrint('=== TripService.rejectOffer() END ===');
    }
  }

  /// Récupérer les offres (bids) pour un trajet (Client)
  static Future<List<BidOffer>> getTripOffers(String tripId) async {
    debugPrint('=== TripService.getTripOffers() START ===');
    try {
      final response = await HttpClient.get('/m/trips/$tripId/offers');
      debugPrint('📊 Response Status: ${response.statusCode}');
      
      if (response.isSuccess) {
        final rawData = response.json['data'];
        List<dynamic> offersJson = [];
        
        if (rawData is List) {
          offersJson = rawData;
        } else if (rawData is Map) {
          if (rawData['data'] is List) {
            offersJson = rawData['data'];
          } else if (rawData['offers'] is List) {
            offersJson = rawData['offers'];
          }
        }
        
        debugPrint('📊 parsed offers count: ${offersJson.length}');
        return offersJson.map((json) => BidOffer.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to fetch offers');
      }
    } catch (e) {
      debugPrint('❌ Erreur getTripOffers: $e');
      return [];
    } finally {
      debugPrint('=== TripService.getTripOffers() END ===');
    }
  }

  /// Fetch trip status from the CLIENT side (no driver role required).
  /// Backend: GET /m/trips/{id}
  static Future<String?> getClientTripStatus(String tripId) async {
    try {
      final response = await HttpClient.get('/m/trips/$tripId');
      if (response.isSuccess) {
        final data = response.json['data']?['data'] ?? response.json['data'] ?? response.json;
        return data['status'] as String?;
      }
    } catch (e) {
      debugPrint('❌ TripService.getClientTripStatus: $e');
    }
    return null;
  }

  /// Fetch current driver GPS position for a client's active trip.
  /// Backend: GET /m/trips/{id}/driver-location
  static Future<DriverLocationDto?> getDriverLocation(String tripId) async {
    try {
      final response = await HttpClient.get('/m/trips/$tripId/driver-location');
      if (response.isSuccess) {
        // API: { data: { message, data: { lat, lng, heading } } }
        final outer = response.json['data'];
        final raw = (outer is Map && outer['data'] is Map)
            ? outer['data'] as Map<String, dynamic>
            : (outer as Map<String, dynamic>? ?? response.json as Map<String, dynamic>);
        final lat = (raw['lat'] ?? raw['latitude'] as num?)?.toDouble();
        final lng = (raw['lng'] ?? raw['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return DriverLocationDto(
          latitude: lat,
          longitude: lng,
          heading: (raw['heading'] as num?)?.toDouble(),
        );
      }
    } catch (e) {
      debugPrint('❌ TripService.getDriverLocation: $e');
    }
    return null;
  }
}

class DriverLocationDto {
  final double latitude;
  final double longitude;
  final double? heading;

  const DriverLocationDto({
    required this.latitude,
    required this.longitude,
    this.heading,
  });
}

class TripException implements Exception {
  final String message;
  final int? statusCode;

  TripException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

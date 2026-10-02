import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/trip_models.dart';
import '../core/network/http_client.dart';
import 'location_tracking_service.dart';
import 'profile_service.dart';

class FareEstimate {
  final double estimatedFare;
  final String currency;
  final String? zoneName;
  final double minBid;   // estimatedFare * 0.8
  final double maxBid;   // estimatedFare * 1.5
  final Map<String, dynamic> breakdown;

  FareEstimate({
    required this.estimatedFare,
    required this.currency,
    this.zoneName,
    required this.breakdown,
  })  : minBid = double.parse((estimatedFare * 0.8).toStringAsFixed(3)),
        maxBid = double.parse((estimatedFare * 1.5).toStringAsFixed(3));

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    final fareRaw = json['estimatedFare'] ?? json['estimated_fare'];
    final fare = (fareRaw as num).toDouble();
    return FareEstimate(
      estimatedFare: fare,
      currency: json['currency'] as String? ?? 'TND',
      zoneName: json['zone_name'] as String?,
      breakdown: (json['pricing_breakdown'] as Map<String, dynamic>?)
          ?? (json['breakdown'] as Map<String, dynamic>?)
          ?? {},
    );
  }

  // Additive multi-stop fields — `pricing_breakdown` uses `extra_stop_fee`,
  // the flattened `/trips/estimate-fare` breakdown uses `extra_stop`.
  double? get extraStopFee {
    final raw = breakdown['extra_stop_fee'] ?? breakdown['extra_stop'];
    return raw is num ? raw.toDouble() : null;
  }

  int? get stopsCount {
    final raw = breakdown['stops_count'];
    return raw is num ? raw.toInt() : null;
  }
}

class TripClientSnapshot {
  final String? status;
  final int? driversViewedCount;

  const TripClientSnapshot({
    required this.status,
    required this.driversViewedCount,
  });
}

class TripStopInput {
  final String address;
  final double latitude;
  final double longitude;
  final double legDistanceKm;
  final double legDurationMin;

  const TripStopInput({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.legDistanceKm,
    required this.legDurationMin,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'leg_distance_km': double.parse(legDistanceKm.toStringAsFixed(2)),
        'leg_duration_min': double.parse(legDurationMin.toStringAsFixed(1)),
      };
}

class TripService {

  /// POST /m/trips/estimate
  /// Retourne le tarif estimé dans la devise de la zone détectée via les coordonnées GPS.
  static Future<FareEstimate> estimateFare({
    required String serviceId,
    required double distanceKm,
    required double durationMinutes,
    double? latitude,
    double? longitude,
    List<Map<String, double>>? legs,
  }) async {
    final body = <String, dynamic>{
      'service_id': serviceId,
      'distance_km': double.parse(distanceKm.toStringAsFixed(2)),
      'duration_minutes': double.parse(durationMinutes.toStringAsFixed(1)),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (legs != null && legs.isNotEmpty)
        'legs': legs
            .map((l) => {
                  'distance_km': double.parse(l['distance_km']!.toStringAsFixed(2)),
                  'duration_min': double.parse(l['duration_min']!.toStringAsFixed(1)),
                })
            .toList(),
    };

    // Per backend spec: POST /m/trips/estimate — fallback to old endpoint if not yet deployed
    HttpResponse response = await HttpClient.post('/m/trips/estimate', body: body);
    if (response.statusCode == 404) {
      response = await HttpClient.post('/m/trips/estimate-fare', body: body);
    }
    if (response.statusCode == 404) {
      response = await HttpClient.post('/trips/estimate-fare', body: body);
    }

    if (!response.isSuccess) {
      throw TripException(
        message: response.json['message'] ?? 'Fare estimation failed',
        statusCode: response.statusCode,
      );
    }

    // Réponse : { data: { data: { estimated_fare, currency, zone_name, pricing_breakdown } } }
    final l1 = response.json['data'];
    final l2 = (l1 is Map && l1['data'] is Map) ? l1['data'] as Map : l1 as Map? ?? {};
    final payload = (l2['data'] is Map)
        ? l2['data'] as Map<String, dynamic>
        : Map<String, dynamic>.from(l2);

    return FareEstimate.fromJson(payload);
  }

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
    String? currency,
    List<TripStopInput>? stops,
    double? leg1DistanceKm,
    double? leg1DurationMin,
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
        if (currency != null) 'currency': currency,
        if (stops != null && stops.isNotEmpty)
          'stops': stops.map((s) => s.toJson()).toList(),
        if (leg1DistanceKm != null)
          'leg1_distance_km': double.parse(leg1DistanceKm.toStringAsFixed(2)),
        if (leg1DurationMin != null)
          'leg1_duration_min': double.parse(leg1DurationMin.toStringAsFixed(1)),
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
        // Course acceptée : la position du chauffeur part en continu (cadence rapide, avec tripId)
        unawaited(LocationTrackingService().setActiveTrip(tripId));
      } else {
        debugPrint('❌ Failed to accept trip. Status: ${response.statusCode}');
        throw Exception('Failed to accept trip: ${response.body}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'acceptation de la course: $e');
      throw Exception('Erreur de connexion lors de l\'acceptation');
    } finally {
      debugPrint('=== TripService.acceptTrip() END ===');
    }
  }
  /// Notifie le backend que ce livreur refuse ce trip.
  /// Le backend doit garder le trip disponible pour les autres livreurs.
  /// En cas d'erreur (endpoint absent), on absorbe silencieusement — le refus local reste effectif.
  static Future<void> refuseTrip(String tripId) async {
    try {
      final response = await HttpClient.patch('/l/trips/$tripId/refuse');
      debugPrint(response.isSuccess
          ? '✅ TripService: refus envoyé pour $tripId'
          : '⚠️ TripService: refus HTTP ${response.statusCode} — refus local seulement');
    } catch (e) {
      debugPrint('⚠️ TripService: refuseTrip exception ($e) — refus local seulement');
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

  /// Met à jour l'offered_fare d'un trip encore PENDING pour le remettre en
  /// visibilité auprès des livreurs à un tarif plus élevé ("Raise fare").
  /// Endpoint pas encore déployé côté backend au moment de l'écriture —
  /// l'appelant doit gérer l'échec gracieusement (ne pas prétendre au succès).
  static Future<void> updateOfferedFare(String tripId, double newFare) async {
    debugPrint('=== TripService.updateOfferedFare() START ===');
    try {
      final response = await HttpClient.patch(
        '/m/trips/$tripId/fare',
        body: {'offered_fare': double.parse(newFare.toStringAsFixed(3))},
      );
      debugPrint('📊 Response Status: ${response.statusCode}');
      if (!response.isSuccess) {
        throw TripException(
          message: response.json['message'] ?? 'Failed to update fare',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour du tarif: $e');
      if (e is TripException) rethrow;
      throw TripException(message: e.toString(), statusCode: null);
    } finally {
      debugPrint('=== TripService.updateOfferedFare() END ===');
    }
  }

  /// Active/désactive l'auto-accept d'une offre <= maxFare venant d'un
  /// livreur à <= maxDriverEtaMinutes de distance. Doit fonctionner même
  /// app fermée, donc entièrement porté côté backend — endpoint pas encore
  /// déployé au moment de l'écriture, l'appelant doit gérer l'échec.
  static Future<void> setAutoAccept(
    String tripId, {
    required bool enabled,
    double? maxFare,
    int? maxDriverEtaMinutes,
  }) async {
    debugPrint('=== TripService.setAutoAccept() START ===');
    try {
      final response = await HttpClient.patch(
        '/m/trips/$tripId/auto-accept',
        body: {
          'enabled': enabled,
          if (maxFare != null) 'max_fare': double.parse(maxFare.toStringAsFixed(3)),
          if (maxDriverEtaMinutes != null) 'max_driver_eta_minutes': maxDriverEtaMinutes,
        },
      );
      debugPrint('📊 Response Status: ${response.statusCode}');
      if (!response.isSuccess) {
        throw TripException(
          message: response.json['message'] ?? 'Failed to update auto-accept',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de l\'auto-accept: $e');
      if (e is TripException) rethrow;
      throw TripException(message: e.toString(), statusCode: null);
    } finally {
      debugPrint('=== TripService.setAutoAccept() END ===');
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
    final snapshot = await getClientTripSnapshot(tripId);
    return snapshot?.status;
  }

  /// Fetch live client-side trip counters and status.
  /// Backend: GET /m/trips/{id}
  static Future<TripClientSnapshot?> getClientTripSnapshot(String tripId) async {
    try {
      final response = await HttpClient.get('/m/trips/$tripId');
      if (response.isSuccess) {
        final data = response.json['data']?['data'] ?? response.json['data'] ?? response.json;
        if (data is! Map) return null;
        return TripClientSnapshot(
          status: data['status']?.toString(),
          driversViewedCount: _parseOptionalInt(
            data['drivers_viewed_count'] ??
                data['driversViewedCount'] ??
                data['viewed_count'] ??
                data['viewedCount'] ??
                data['seen_count'] ??
                data['seenCount'] ??
                data['notified_drivers_count'] ??
                data['notifiedDriversCount'],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ TripService.getClientTripSnapshot: $e');
    }
    return null;
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Fetch full trip detail for client when a driver accepted directly (no bid).
  /// Backend: GET /m/trips/{id}
  static Future<AcceptedTripDetail?> getClientTripAcceptedDetail(String tripId) async {
    try {
      final response = await HttpClient.get('/m/trips/$tripId');
      if (response.isSuccess) {
        final raw = response.json['data']?['data'] ?? response.json['data'] ?? response.json;
        if (raw is! Map) return null;
        final driver = raw['driver'] as Map<String, dynamic>?
            ?? raw['livreur'] as Map<String, dynamic>?;
        final fareRaw = raw['fare'] ?? raw['offered_fare'] ?? raw['estimated_fare'];
        final fullName = driver != null
            ? '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim()
            : '';
        return AcceptedTripDetail(
          status: raw['status'] as String? ?? '',
          fare: fareRaw is num ? fareRaw.toDouble() : 0.0,
          currency: raw['currency'] as String? ?? 'TND',
          driverName: fullName.isNotEmpty
              ? fullName
              : (driver?['name'] as String?
                  ?? driver?['full_name'] as String?
                  ?? 'Chauffeur'),
          driverPhone: driver?['phone'] as String?,
          driverPhoto: ProfileService.resolveAvatarUrl(
              driver?['profile_picture'] as String?
                  ?? driver?['photo'] as String?
                  ?? driver?['avatar'] as String?),
          driverRating: (driver?['rating'] as num?)?.toDouble() ?? 4.5,
          driverVehicle: driver?['vehicle'] as String?
              ?? raw['vehicle_description'] as String?
              ?? '',
        );
      }
    } catch (e) {
      debugPrint('❌ TripService.getClientTripAcceptedDetail: $e');
    }
    return null;
  }

  /// Fetch current driver GPS position for a client's active trip.
  /// Backend: GET /m/trips/{id}/driver-location
  ///
  /// Retourne null tant que le chauffeur n'a pas de position (404
  /// `driver_location_unavailable` : continuer à sonder). Lève
  /// [TripNotActiveException] sur 409 `trip_not_active` : la course est
  /// terminée, il faut ARRÊTER de sonder.
  static Future<DriverLocationDto?> getDriverLocation(String tripId) async {
    try {
      final response = await HttpClient.get('/m/trips/$tripId/driver-location');
      if (response.isSuccess) {
        // API: { message, data: { tripId, latitude, longitude, heading, speed, accuracy, timestamp, updatedAt } }
        final json = response.json;
        final outer = json['data'];
        final raw = (outer is Map && outer['data'] is Map)
            ? Map<String, dynamic>.from(outer['data'] as Map)
            : (outer is Map ? Map<String, dynamic>.from(outer) : json);
        final lat = ((raw['latitude'] ?? raw['lat']) as num?)?.toDouble();
        final lng = ((raw['longitude'] ?? raw['lng']) as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return DriverLocationDto(
          latitude: lat,
          longitude: lng,
          heading: (raw['heading'] as num?)?.toDouble(),
          speed: (raw['speed'] as num?)?.toDouble(),
          accuracy: (raw['accuracy'] as num?)?.toDouble(),
        );
      }
    } on ApiException catch (e) {
      final code = _errorCode(e);
      if (e.response?.statusCode == 409 && code == 'trip_not_active') {
        throw TripNotActiveException();
      }
      // 404 driver_location_unavailable, 400 no_driver_assigned, réseau… : on réessaiera
    } catch (e) {
      debugPrint('❌ TripService.getDriverLocation: ${e.runtimeType}');
    }
    return null;
  }

  /// `error.code` (ou `code`) du corps d'erreur du backend.
  static String? _errorCode(ApiException e) {
    try {
      final body = e.response?.body;
      if (body == null || body.isEmpty) return null;
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final err = json['error'];
      return ((err is Map ? err['code'] : null) ?? json['code'])?.toString();
    } catch (_) {
      return null;
    }
  }
}

/// La course n'est plus active côté serveur (terminée / annulée / expirée).
class TripNotActiveException implements Exception {
  @override
  String toString() => 'trip_not_active';
}

class DriverLocationDto {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed; // m/s
  final double? accuracy; // m

  const DriverLocationDto({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
  });
}

class AcceptedTripDetail {
  final String status;
  final double fare;
  final String currency;
  final String driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final double driverRating;
  final String driverVehicle;

  const AcceptedTripDetail({
    required this.status,
    required this.fare,
    required this.currency,
    required this.driverName,
    this.driverPhone,
    this.driverPhoto,
    required this.driverRating,
    required this.driverVehicle,
  });
}

class TripException implements Exception {
  final String message;
  final int? statusCode;

  TripException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

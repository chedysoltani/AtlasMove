class TripResponse {
  final bool success;
  final String message;
  final TripData? data;
  
  TripResponse({
    required this.success,
    required this.message,
    this.data,
  });
  
  factory TripResponse.fromJson(Map<String, dynamic> json) {
    // Gérer le format de l'API: {data: {message: ..., data: {...}}}
    if (json['data'] != null) {
      final apiData = json['data'];
      return TripResponse(
        success: true,
        message: apiData['message'] ?? '',
        data: apiData['data'] != null ? TripData.fromJson(apiData['data']) : null,
      );
    }
    
    // Format fallback
    return TripResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? TripData.fromJson(json['data']) : null,
    );
  }
}

class TripData {
  final String id;
  final String status;
  final double estimatedFare;
  final String currency;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicle;
  final int? estimatedArrivalMinutes;
  
  TripData({
    required this.id,
    required this.status,
    required this.estimatedFare,
    required this.currency,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.estimatedArrivalMinutes,
  });
  
  factory TripData.fromJson(Map<String, dynamic> json) {
    // Utiliser directement offered_fare ou estimated_fare de la réponse API
    double estimatedFare = double.tryParse((json['offered_fare'] ?? json['offeredFare'] ?? json['estimated_fare'] ?? json['estimatedFare'])?.toString() ?? '0') ?? 0.0;
    String currency = json['currency']?.toString() ?? 'TND';

    // Fallback: utiliser les données du service si estimated_fare n'est pas disponible
    if (estimatedFare == 0.0 && json['service'] != null) {
      final service = json['service'];
      final basePrice = double.tryParse(service['base_price']?.toString() ?? '0') ?? 0.0;
      final pricePerKm = double.tryParse(service['price_per_km']?.toString() ?? '0') ?? 0.0;
      final minimumFare = double.tryParse(service['minimum_fare']?.toString() ?? '0') ?? 0.0;
      currency = service['currency']?.toString() ?? 'TND';
      
      // Calcul du tarif: base + prix au km (avec minimum)
      final calculatedFare = basePrice + (pricePerKm * 1.67); // distance moyenne de 1.67km
      estimatedFare = calculatedFare > minimumFare ? calculatedFare : minimumFare;
    }
    
    return TripData(
      id: json['id']?.toString() ?? '',
      status: json['livreur_id'] == null ? 'pending' : 'searching', // Statut basé sur la présence d'un livreur
      estimatedFare: estimatedFare,
      currency: currency,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverVehicle: json['driver_vehicle'],
      estimatedArrivalMinutes: json['estimated_arrival_minutes'],
    );
  }
}

enum TripStatus {
  pending('pending', 'En attente'),
  searching('searching', 'Recherche de livreur'),
  accepted('accepted', 'Course acceptée'),
  arriving('livreur_en_route', 'Livreur en route'),
  inProgress('in_progress', 'Course en cours'),
  completed('completed', 'Course terminée'),
  cancelled('cancelled', 'Course annulée'),
  expired('expired', 'Course expirée');

  const TripStatus(this.value, this.label);
  final String value;
  final String label;

  static TripStatus fromString(String value) {
    // Handle all backend cancelled variants
    if (value == 'cancelled_by_client' ||
        value == 'cancelled_by_livreur' ||
        value == 'cancelled_by_admin') {
      return TripStatus.cancelled;
    }
    return TripStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TripStatus.pending,
    );
  }
}

class AvailableTrip {
  final String id;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final double estimatedDistanceKm;
  final double estimatedFare;
  final String currency;
  final String status;
  final String serviceName;
  final double? distanceToPickupKm; // The distance_km computed by SQL
  final String? clientId;
  String? clientName; // May be null if backend doesn't join client, mutable to fetch later
  final String? clientPhone;
  final bool isNegotiable;
  final double? offeredFare;
  
  AvailableTrip({
    required this.id,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.estimatedDistanceKm,
    required this.estimatedFare,
    required this.currency,
    required this.status,
    required this.serviceName,
    this.distanceToPickupKm,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.isNegotiable = true,
    this.offeredFare,
  });

  factory AvailableTrip.fromJson(Map<String, dynamic> json) {
    // Parser le service
    String serviceName = 'Inconnu';
    if (json['service'] != null && json['service']['name'] != null) {
      serviceName = json['service']['name'].toString();
    }

    // Tenter de récupérer le nom du client si le backend l'a inclus
    String? clientName;
    String? clientPhone;
    if (json['client'] != null) {
      final firstName = json['client']['first_name']?.toString() ?? '';
      final lastName = json['client']['last_name']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        clientName = '$firstName $lastName'.trim();
      }
      clientPhone = json['client']['phone']?.toString();
    }

    return AvailableTrip(
      id: json['id']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? 'Adresse inconnue',
      pickupLatitude: double.tryParse(json['pickup_latitude']?.toString() ?? '0') ?? 0.0,
      pickupLongitude: double.tryParse(json['pickup_longitude']?.toString() ?? '0') ?? 0.0,
      destinationAddress: json['destination_address']?.toString() ?? 'Adresse inconnue',
      destinationLatitude: double.tryParse(json['destination_latitude']?.toString() ?? '0') ?? 0.0,
      destinationLongitude: double.tryParse(json['destination_longitude']?.toString() ?? '0') ?? 0.0,
      estimatedDistanceKm: double.tryParse(json['estimated_distance_km']?.toString() ?? '0') ?? 0.0,
      estimatedFare: double.tryParse(json['estimated_fare']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'TND',
      status: json['status']?.toString() ?? 'pending',
      serviceName: serviceName,
      distanceToPickupKm: json['distance_km'] != null ? 
          double.tryParse(json['distance_km'].toString()) : null,
      clientId: json['client_id']?.toString(),
      clientName: clientName,
      clientPhone: clientPhone,
      isNegotiable: json['is_negotiable'] ?? true,
      offeredFare: json['offered_fare'] != null ? double.tryParse(json['offered_fare'].toString()) : null,
    );
  }
}
class TripHistoryItem {
  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final String serviceName;
  final double estimatedFare;
  final String currency;
  final DateTime createdAt;
  final double estimatedDistanceKm;
  final int estimatedDurationMin;

  TripHistoryItem({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.serviceName,
    required this.estimatedFare,
    required this.currency,
    required this.createdAt,
    required this.estimatedDistanceKm,
    required this.estimatedDurationMin,
  });

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    String serviceName = 'Inconnu';
    if (json['service'] != null && json['service']['name'] != null) {
      serviceName = json['service']['name'].toString();
    }

    return TripHistoryItem(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      pickupAddress: json['pickup_address']?.toString() ?? 'Adresse inconnue',
      destinationAddress: json['destination_address']?.toString() ?? 'Adresse inconnue',
      serviceName: serviceName,
      estimatedFare: double.tryParse((json['offered_fare'] ?? json['offeredFare'] ?? json['estimated_fare'] ?? json['estimatedFare'])?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'TND',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
      estimatedDistanceKm: double.tryParse(json['estimated_distance_km']?.toString() ?? '0') ?? 0.0,
      estimatedDurationMin: int.tryParse(json['estimated_duration_min']?.toString() ?? '0') ?? 0,
    );
  }
}

class TripHistoryResponse {
  final List<TripHistoryItem> trips;
  final int total;
  final int page;
  final int limit;

  TripHistoryResponse({
    required this.trips,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory TripHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final tripsList = data['data'] as List? ?? [];
    
    return TripHistoryResponse(
      trips: tripsList.map((t) => TripHistoryItem.fromJson(t as Map<String, dynamic>)).toList(),
      total: int.tryParse(data['total']?.toString() ?? '0') ?? 0,
      page: int.tryParse(data['page']?.toString() ?? '1') ?? 1,
      limit: int.tryParse(data['limit']?.toString() ?? '10') ?? 10,
    );
  }
}

class ClientDashboardStats {
  final int totalTrips;
  final double totalSpent;
  final String currency;
  final int upcomingRendezvous;

  const ClientDashboardStats({
    required this.totalTrips,
    required this.totalSpent,
    required this.currency,
    required this.upcomingRendezvous,
  });
}

class BidOffer {
  final String id;
  final String tripId;
  final String livreurId;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
  final String driverVehicle;
  final double proposedFare;
  final String status; // "pending", "countered", "accepted", "rejected"

  BidOffer({
    required this.id,
    required this.tripId,
    required this.livreurId,
    required this.driverName,
    this.driverPhoto,
    required this.driverRating,
    required this.driverVehicle,
    required this.proposedFare,
    required this.status,
  });

  factory BidOffer.fromJson(Map<String, dynamic> json) {
    return BidOffer(
      id: json['id']?.toString() ?? '',
      tripId: (json['trip_id'] ?? json['tripId'])?.toString() ?? '',
      livreurId: (json['livreur_id'] ?? json['livreurId'])?.toString() ?? '',
      driverName: (json['driver_name'] ?? json['driverName'] ?? json['driver']?['fullName'] ?? json['driver']?['name'])?.toString() ?? 'Livreur',
      driverPhoto: (json['driver_photo'] ?? json['driverPhoto'] ?? json['driver']?['photo'])?.toString(),
      driverRating: double.tryParse((json['driver_rating'] ?? json['driverRating'] ?? json['driver']?['rating'] ?? json['driver']?['stars'])?.toString() ?? '4.8') ?? 4.8,
      driverVehicle: (json['driver_vehicle'] ?? json['driverVehicle'] ?? json['driver']?['vehicle'] ?? json['driver']?['vehicle_type'])?.toString() ?? 'Moto standard',
      proposedFare: double.tryParse((json['proposed_fare'] ?? json['proposedFare'] ?? json['proposed_price'])?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

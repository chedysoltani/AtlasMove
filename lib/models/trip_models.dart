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
    // Utiliser directement estimated_fare de la réponse API
    double estimatedFare = double.tryParse(json['estimated_fare']?.toString() ?? '0') ?? 0.0;
    String currency = json['currency']?.toString() ?? 'MAD';
    
    // Fallback: utiliser les données du service si estimated_fare n'est pas disponible
    if (estimatedFare == 0.0 && json['service'] != null) {
      final service = json['service'];
      final basePrice = double.tryParse(service['base_price']?.toString() ?? '0') ?? 0.0;
      final pricePerKm = double.tryParse(service['price_per_km']?.toString() ?? '0') ?? 0.0;
      final minimumFare = double.tryParse(service['minimum_fare']?.toString() ?? '0') ?? 0.0;
      currency = service['currency']?.toString() ?? 'MAD';
      
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
  arriving('arriving', 'Livreur en route'),
  inProgress('in_progress', 'Course en cours'),
  completed('completed', 'Course terminée'),
  cancelled('cancelled', 'Course annulée');
  
  const TripStatus(this.value, this.label);
  final String value;
  final String label;
  
  static TripStatus fromString(String value) {
    return TripStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TripStatus.pending,
    );
  }
}

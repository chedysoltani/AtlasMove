class Rendezvous {
  final String id;
  final String serviceId;
  final String serviceName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? details;
  final String address;
  final double latitude;
  final double longitude;
  final String status; // pending, accepted, completed, cancelled
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? livreurId;
  final String? livreurName;
  final String? livreurPhone;
  final DateTime createdAt;

  // Commission & payment fields
  final double? finalFare;
  final String? currency;
  final double? commissionAmount;
  final DateTime? completedAt;

  // Negotiation flag
  final bool isNegotiable;

  // Delivery-specific fields (null for standard RDV services)
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? cargoDescription;
  final double? cargoWeightKg;
  final String? cargoSize; // 'small' | 'medium' | 'large' | 'extra_large'
  final bool? isFragile;
  final double? estimatedDistanceKm;
  final double? estimatedFare;

  const Rendezvous({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledAt,
    required this.durationMinutes,
    this.details,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.livreurId,
    this.livreurName,
    this.livreurPhone,
    required this.createdAt,
    this.finalFare,
    this.currency,
    this.commissionAmount,
    this.completedAt,
    this.isNegotiable = false,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.cargoDescription,
    this.cargoWeightKg,
    this.cargoSize,
    this.isFragile,
    this.estimatedDistanceKm,
    this.estimatedFare,
  });

  bool get isDelivery => destinationAddress != null && destinationAddress!.isNotEmpty;

  bool get isCancellable => status == 'pending' || status == 'accepted';
  bool get isUpcoming =>
      status == 'pending' || status == 'accepted';
  bool get isPast =>
      status == 'completed' || status == 'cancelled';

  factory Rendezvous.fromJson(Map<String, dynamic> json) {
    String serviceName = 'Service';
    if (json['service'] is Map) {
      serviceName = json['service']['name']?.toString() ?? serviceName;
    } else if (json['service_name'] != null) {
      serviceName = json['service_name'].toString();
    }

    String? clientName;
    String? clientPhone;
    if (json['client'] is Map) {
      final c = json['client'] as Map;
      final fn = c['first_name']?.toString() ?? '';
      final ln = c['last_name']?.toString() ?? '';
      final full = '$fn $ln'.trim();
      clientName = full.isEmpty ? null : full;
      clientPhone = c['phone']?.toString();
    } else {
      // List endpoints return flat fields instead of nested object
      final flat = json['client_name']?.toString();
      clientName = (flat != null && flat.isNotEmpty) ? flat : null;
      clientPhone = json['client_phone']?.toString();
    }

    String? livreurName;
    String? livreurPhone;
    if (json['livreur'] is Map) {
      final l = json['livreur'] as Map;
      final fn = l['first_name']?.toString() ?? '';
      final ln = l['last_name']?.toString() ?? '';
      final full = '$fn $ln'.trim();
      livreurName = full.isEmpty ? null : full;
      livreurPhone = l['phone']?.toString();
    }

    return Rendezvous(
      id: json['id']?.toString() ?? '',
      serviceId: (json['service_id'] ?? json['serviceId'])?.toString() ?? '',
      serviceName: serviceName,
      scheduledAt:
          DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ??
              DateTime.now(),
      durationMinutes:
          int.tryParse(json['duration_minutes']?.toString() ?? '60') ?? 60,
      details: json['details']?.toString(),
      address: (json['pickup_address'] ?? json['address'])?.toString() ?? '',
      latitude: double.tryParse(
              (json['pickup_latitude'] ?? json['latitude'])?.toString() ?? '0') ??
          0.0,
      longitude: double.tryParse(
              (json['pickup_longitude'] ?? json['longitude'])?.toString() ?? '0') ??
          0.0,
      status: json['status']?.toString() ?? 'pending',
      clientId: (json['client_id'] ?? json['clientId'])?.toString(),
      clientName: clientName,
      clientPhone: clientPhone,
      livreurId: (json['livreur_id'] ?? json['livreurId'])?.toString(),
      livreurName: livreurName,
      livreurPhone: livreurPhone,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      finalFare: double.tryParse(json['final_fare']?.toString() ?? ''),
      currency: json['currency']?.toString(),
      commissionAmount: double.tryParse(
          json['commission_amount']?.toString() ?? ''),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      destinationAddress: json['destination_address']?.toString(),
      destinationLatitude: double.tryParse(
          json['destination_latitude']?.toString() ?? ''),
      destinationLongitude: double.tryParse(
          json['destination_longitude']?.toString() ?? ''),
      cargoDescription: json['cargo_description']?.toString(),
      cargoWeightKg: double.tryParse(
          json['cargo_weight_kg']?.toString() ?? ''),
      cargoSize: json['cargo_size']?.toString(),
      isFragile: json['is_fragile'] as bool?,
      estimatedDistanceKm: double.tryParse(
          json['estimated_distance_km']?.toString() ?? ''),
      estimatedFare: double.tryParse(
          json['estimated_fare']?.toString() ?? ''),
      isNegotiable: json['is_negotiable'] == true,
    );
  }
}

class RendezvousEstimate {
  final double estimatedFare;
  final String currency;
  final String? zoneName;

  const RendezvousEstimate({
    required this.estimatedFare,
    required this.currency,
    this.zoneName,
  });

  factory RendezvousEstimate.fromJson(Map<String, dynamic> json) {
    return RendezvousEstimate(
      estimatedFare: double.tryParse(
              json['estimated_fare']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
      zoneName: json['zone_name']?.toString(),
    );
  }
}

class RendezvousOffer {
  final String id;
  final String rdvId;
  final String proposedBy; // 'client' | 'driver'
  final double proposedFare;
  final String currency;
  final String status; // 'pending' | 'accepted' | 'rejected' | 'countered'
  final DateTime createdAt;

  const RendezvousOffer({
    required this.id,
    required this.rdvId,
    required this.proposedBy,
    required this.proposedFare,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCountered => status == 'countered';

  factory RendezvousOffer.fromJson(Map<String, dynamic> json) {
    return RendezvousOffer(
      id: json['id']?.toString() ?? '',
      rdvId: (json['rendezvous_id'] ?? json['rdv_id'])?.toString() ?? '',
      proposedBy: json['proposed_by']?.toString() ?? 'driver',
      proposedFare: double.tryParse(json['proposed_fare']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class RendezvousListResponse {
  final List<Rendezvous> items;
  final int total;
  final int page;
  final int limit;

  const RendezvousListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory RendezvousListResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> rawList = [];
    int total = 0;
    int page = 1;
    int limit = 10;

    // Handles nested format: { data: { message, data: { data: [...], total, page, limit } } }
    // or simpler: { data: { data: [...], total } }
    final outer = json['data'];
    if (outer is Map<String, dynamic>) {
      final inner = outer['data'];
      if (inner is Map<String, dynamic>) {
        rawList = inner['data'] as List? ?? [];
        total = int.tryParse(inner['total']?.toString() ?? '0') ?? 0;
        page = int.tryParse(inner['page']?.toString() ?? '1') ?? 1;
        limit = int.tryParse(inner['limit']?.toString() ?? '10') ?? 10;
      } else if (inner is List) {
        rawList = inner;
        total = int.tryParse(outer['total']?.toString() ?? '0') ?? rawList.length;
      } else {
        // Might be a flat list directly in data
        rawList = outer['items'] as List? ?? outer['rendezvous'] as List? ?? [];
        total = rawList.length;
      }
    } else if (outer is List) {
      rawList = outer;
      total = rawList.length;
    }

    return RendezvousListResponse(
      items: rawList
          .map((j) => Rendezvous.fromJson(j as Map<String, dynamic>))
          .toList(),
      total: total,
      page: page,
      limit: limit,
    );
  }
}

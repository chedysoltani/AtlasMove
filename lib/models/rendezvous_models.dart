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
  });

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
      address: json['address']?.toString() ?? '',
      latitude:
          double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude:
          double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
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

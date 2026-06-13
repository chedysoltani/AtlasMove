class Service {
  final String id;
  final String name;
  final String? description;
  final String categoryId;
  final ServiceCategory? category;
  final String transportType;
  final String pricingModel;
  final bool isActive;
  final bool requiresDocument;
  final String? requiredDocumentsDescription;
  final String? documentUrl;
  final double? basePrice;
  final double? pricePerKm;
  final double? pricePerMinute;
  final double? minimumFare;
  final String? currency;
  final int? maxCapacity;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Service({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.category,
    required this.transportType,
    required this.pricingModel,
    required this.isActive,
    this.requiresDocument = false,
    this.requiredDocumentsDescription,
    this.documentUrl,
    this.basePrice,
    this.pricePerKm,
    this.pricePerMinute,
    this.minimumFare,
    this.currency,
    this.maxCapacity,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
  print('DEBUG: Service.fromJson - parsing service with keys: ${json.keys.toList()}');

  // Helper function pour parser les champs en toute sécurité
  T? safeParse<T>(String key, T Function(String) parser) {
    final value = json[key];
    if (value == null) {
      print('DEBUG: Service.fromJson - $key is null');
      return null;
    }
    try {
      return parser(value.toString());
    } catch (e) {
      print('DEBUG: Service.fromJson - Error parsing $key: $value -> $e');
      return null;
    }
  }

  final categoryJson = json['category'];

  return Service(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    categoryId: json['category_id'] ?? '',

    // ✅ FIX CATEGORY
    category: categoryJson != null
        ? ServiceCategory.fromJson(categoryJson)
        : null,

    // ✅ FIX TRANSPORT TYPE
    transportType: categoryJson != null
        ? categoryJson['transport_type'] ?? ''
        : '',

    pricingModel: json['pricing_model'] ?? '',
    isActive: json['is_active'] ?? true,
    requiresDocument: json['requires_document'] ?? false,
    requiredDocumentsDescription: json['required_documents_description'],
    documentUrl: json['document_url'],

    basePrice: safeParse<double>('base_price', double.parse),
    pricePerKm: safeParse<double>('price_per_km', double.parse),
    pricePerMinute: safeParse<double>('price_per_minute', double.parse),
    minimumFare: safeParse<double>('minimum_fare', double.parse),

    currency: json['currency'] ?? 'TND',
    maxCapacity: safeParse<int>('max_capacity', int.parse),
    sortOrder: safeParse<int>('sort_order', int.parse) ?? 0,

    // ✅ FIX DATES (anti-crash)
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'category_name': category?.name,
      'transport_type': transportType,
      'pricing_model': pricingModel,
      'is_active': isActive,
      'requires_document': requiresDocument,
      'document_url': documentUrl,
      'base_price': basePrice,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ServiceCategory {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String transportType;
  final String status;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.transportType,
    required this.status,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    print('DEBUG: ServiceCategory.fromJson - parsing category with keys: ${json.keys.toList()}');
    
    return ServiceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      transportType: json['transport_type'] as String,
      status: json['status'] as String? ?? 'active',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'transport_type': transportType,
      'status': status,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ServiceAssignment {
  final String id;
  final String serviceId;
  final String serviceName;
  final String driverId;
  final String status;
  final String? documentUrl;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;

  ServiceAssignment({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.driverId,
    required this.status,
    this.documentUrl,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.rejectedAt,
  });

  factory ServiceAssignment.fromJson(Map<String, dynamic> json) {
    try {
      // Gérer les deux structures possibles :
      // 1. Assignement actuel: {data: {message: "...", data: {...}}}
      // 2. Historique: {data: {id: ..., service: {...}}}
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        print('DEBUG: ServiceAssignment.fromJson - data est null');
        throw Exception('data est null');
      }
      
      // Vérifier si les données sont dans data.data (assignement actuel) ou directement dans data (historique)
      Map<String, dynamic>? assignmentData;
      
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        // Structure assignement actuel: {data: {data: {...}}}
        assignmentData = data['data'] as Map<String, dynamic>;
        print('DEBUG: ServiceAssignment.fromJson - Structure assignement actuel détectée');
      } else if (data.containsKey('id')) {
        // Structure historique: {data: {id: ..., service: {...}}}
        assignmentData = data;
        print('DEBUG: ServiceAssignment.fromJson - Structure historique détectée');
      } else {
        print('DEBUG: ServiceAssignment.fromJson - Structure non reconnue: ${data.keys.toList()}');
        throw Exception('Structure de réponse non reconnue');
      }
      
      // assignmentData ne peut pas être null ici grâce à la logique ci-dessus
      
      print('DEBUG: ServiceAssignment.fromJson - assignmentData keys: ${assignmentData.keys.toList()}');
      
      // Parsing sécurisé avec gestion complète des null
      final id = assignmentData['id']?.toString() ?? '';
      final serviceId = assignmentData['service_id']?.toString() ?? '';
      
      // Parsing du service avec null safety
      String serviceName = 'Service inconnu';
      final service = assignmentData['service'];
      if (service is Map<String, dynamic>) {
        serviceName = service['name']?.toString() ?? 'Service inconnu';
      }
      
      final driverId = assignmentData['livreur_id']?.toString() ?? '';
      final status = assignmentData['status']?.toString() ?? '';
      final documentUrl = assignmentData['document_url']?.toString();
      final rejectionReason = assignmentData['rejection_reason']?.toString();
      
      // Parsing des dates avec gestion des erreurs
      DateTime createdAt = DateTime.now();
      try {
        createdAt = DateTime.parse(assignmentData['created_at']?.toString() ?? '');
      } catch (e) {
        print('DEBUG: ServiceAssignment.fromJson - Erreur parsing created_at: $e');
      }
      
      DateTime updatedAt = DateTime.now();
      try {
        updatedAt = DateTime.parse(assignmentData['updated_at']?.toString() ?? '');
      } catch (e) {
        print('DEBUG: ServiceAssignment.fromJson - Erreur parsing updated_at: $e');
      }
      
      DateTime? approvedAt;
      try {
        if (assignmentData['approved_at'] != null) {
          approvedAt = DateTime.parse(assignmentData['approved_at'].toString());
        }
      } catch (e) {
        print('DEBUG: ServiceAssignment.fromJson - Erreur parsing approved_at: $e');
      }
      
      DateTime? rejectedAt;
      try {
        if (assignmentData['rejected_at'] != null) {
          rejectedAt = DateTime.parse(assignmentData['rejected_at'].toString());
        }
      } catch (e) {
        print('DEBUG: ServiceAssignment.fromJson - Erreur parsing rejected_at: $e');
      }
      
      print('DEBUG: ServiceAssignment.fromJson - Tous les champs parsés avec succès');
      
      return ServiceAssignment(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        driverId: driverId,
        status: status,
        documentUrl: documentUrl?.isEmpty ?? true ? null : documentUrl,
        rejectionReason: rejectionReason,
        createdAt: createdAt,
        updatedAt: updatedAt,
        approvedAt: approvedAt,
        rejectedAt: rejectedAt,
      );
    } catch (e) {
      print('DEBUG: ServiceAssignment.fromJson - Erreur parsing: $e');
      print('DEBUG: ServiceAssignment.fromJson - json reçu: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'service_name': serviceName,
      'driver_id': driverId,
      'status': status,
      'document_url': documentUrl,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isActive => isApproved && (rejectedAt == null);
}

class PaginatedServicesResponse {
  final List<Service> data;
  final PaginationMeta meta;

  PaginatedServicesResponse({
    required this.data,
    required this.meta,
  });

  factory PaginatedServicesResponse.fromJson(Map<String, dynamic> json) {
    print('DEBUG: PaginatedServicesResponse.fromJson - json: $json');
    
    // La réponse API a la structure: {data: {data: [...], total: X}}
    final responseData = json['data'] as Map<String, dynamic>;
    print('DEBUG: responseData: $responseData');
    
    final servicesList = responseData['data'] as List;
    print('DEBUG: servicesList type: ${servicesList.runtimeType}, length: ${servicesList.length}');
    
    final total = responseData['total'] as int;
    print('DEBUG: total: $total');
    
    final services = servicesList
        .map((item) {
          print('DEBUG: Parsing service item: $item');
          return Service.fromJson(item as Map<String, dynamic>);
        })
        .toList();
    
    print('DEBUG: Services parsed count: ${services.length}');
    
    return PaginatedServicesResponse(
      data: services,
      meta: PaginationMeta(
        currentPage: 1,
        totalPages: (total / 10).ceil(),
        totalItems: total,
        itemsPerPage: 10,
        hasNextPage: services.length >= 10,
        hasPreviousPage: false,
      ),
    );
  }
}

class PaginatedAssignmentsResponse {
  final List<ServiceAssignment> data;
  final PaginationMeta meta;

  PaginatedAssignmentsResponse({
    required this.data,
    required this.meta,
  });

  factory PaginatedAssignmentsResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedAssignmentsResponse(
      data: (json['data'] as List)
          .map((item) => ServiceAssignment.fromJson(item as Map<String, dynamic>))
          .toList(),
      meta: PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }
}

class PaginationMeta {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginationMeta({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] as int,
      totalPages: json['total_pages'] as int,
      totalItems: json['total_items'] as int,
      itemsPerPage: json['items_per_page'] as int,
      hasNextPage: json['has_next_page'] as bool,
      hasPreviousPage: json['has_previous_page'] as bool,
    );
  }
}

class ServiceCatalogue {
  final List<ServiceCategoryWithServices> data;
  final int total;

  ServiceCatalogue({
    required this.data,
    required this.total,
  });

  factory ServiceCatalogue.fromJson(Map<String, dynamic> json) {
    print('DEBUG: ServiceCatalogue.fromJson - json keys: ${json.keys.toList()}');
    
    // La réponse de l'API a la structure: {data: {data: [...], total: 5}}
    final dataWrapper = json['data'] as Map<String, dynamic>?;
    print('DEBUG: ServiceCatalogue.fromJson - dataWrapper: $dataWrapper');
    
    final dataList = dataWrapper?['data'] as List? ?? json['data'] as List?;
    print('DEBUG: ServiceCatalogue.fromJson - dataList length: ${dataList?.length}');
    
    if (dataList == null) {
      print('DEBUG: ServiceCatalogue.fromJson - dataList is null');
      return ServiceCatalogue(
        data: [],
        total: 0,
      );
    }

    final data = dataList
        .map((item) => ServiceCategoryWithServices.fromJson(item as Map<String, dynamic>))
        .toList();

    print('DEBUG: ServiceCatalogue.fromJson - parsed ${data.length} categories');

    return ServiceCatalogue(
      data: data,
      total: dataWrapper?['total'] as int? ?? json['total'] as int? ?? data.length,
    );
  }
}

class ServiceCategoryWithServices {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String transportType;
  final String status;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Service> services;

  ServiceCategoryWithServices({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.transportType,
    required this.status,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.services,
  });

  factory ServiceCategoryWithServices.fromJson(Map<String, dynamic> json) {
    final services = (json['services'] as List?)
        ?.map((item) => Service.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    return ServiceCategoryWithServices(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      transportType: json['transport_type'] as String,
      status: json['status'] as String? ?? 'active',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      services: services,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transport type constants — slugs returned by the backend (Phase 2 catalogue)
// ─────────────────────────────────────────────────────────────────────────────
class TransportTypeConstants {
  // Passenger transport
  static const taxiStandard = 'taxi_standard';
  static const taxi = 'taxi'; // legacy slug kept for backwards compat
  static const vtc = 'vtc';
  static const voiture = 'voiture'; // legacy
  static const motoTaxi = 'moto_taxi';
  static const moto = 'moto'; // legacy
  static const tukTuk = 'tuk_tuk';
  static const minibusCollectif = 'minibus_collectif';
  static const busCharter = 'bus_charter';
  static const bus = 'bus'; // legacy
  static const transfertAeroport = 'transfert_aeroport';
  static const transportScolaire = 'transport_scolaire';
  static const voitureLuxe = 'voiture_luxe';
  static const ambulance = 'ambulance';
  static const covoiturage = 'covoiturage';
  static const helicoptere = 'helicoptere';

  // Light delivery < 500 kg
  static const coursierMoto = 'coursier_moto';
  static const livraison = 'livraison'; // legacy
  static const delivery = 'delivery'; // legacy
  static const coursierVelo = 'coursier_velo';
  static const livraisonVoiture = 'livraison_voiture';
  static const camionnette15t = 'camionnette_15t';
  static const van = 'van'; // legacy
  static const tricycleCargo = 'tricycle_cargo';

  // Heavy transport / freight
  static const pickupTruck = 'pickup_truck';
  static const camion35t = 'camion_35t';
  static const camion10t = 'camion_10t';
  static const camion20t = 'camion_20t';
  static const camion = 'camion'; // legacy
  static const semiRemorque = 'semi_remorque';
  static const camionPlateau = 'camion_plateau';
  static const camionBenne = 'camion_benne';
  static const camionFrigo = 'camion_frigo';
  static const camionCiterne = 'camion_citerne';
  static const camionGrue = 'camion_grue';
  static const camionFourgon = 'camion_fourgon';
  static const camionDemenagement = 'camion_demenagement';
  static const camionToupie = 'camion_toupie';

  // Maritime
  static const taxiNautique = 'taxi_nautique';
  static const ferry = 'ferry';
  static const vedetteYacht = 'vedette_yacht';
  static const yacht = 'yacht'; // legacy

  // Agricultural / industrial
  static const tracteurAgricole = 'tracteur_agricole';
  static const tracteur = 'tracteur'; // legacy
  static const chariotElevateur = 'chariot_elevateur';
  static const transportEngins = 'transport_engins';

  // All delivery-type slugs (need pickup + destination address)
  static const Set<String> deliverySlugs = {
    coursierMoto, livraison, delivery, coursierVelo, livraisonVoiture,
    camionnette15t, van, tricycleCargo,
    pickupTruck, camion35t, camion10t, camion20t, camion,
    semiRemorque, camionPlateau, camionBenne, camionFrigo,
    camionCiterne, camionGrue, camionFourgon, camionDemenagement,
    camionToupie, transportEngins,
  };

  // Slugs that do NOT require real-time GPS tracking
  static const Set<String> noTrackingSlugs = {
    minibusCollectif, busCharter, bus, covoiturage,
    ferry, tracteurAgricole, tracteur, chariotElevateur, camionToupie,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper extension on Service
// ─────────────────────────────────────────────────────────────────────────────
extension ServiceHelpers on Service {
  // True when this service is a delivery/transport type (needs pickup + destination)
  bool get isDeliveryService =>
      TransportTypeConstants.deliverySlugs.contains(transportType);

  // True when billing is per hour (uses pricePerMinute field)
  bool get isHourlyService => pricingModel == 'hourly';

  // True when price is fixed regardless of distance
  bool get isFixedPrice => pricingModel == 'fixed';

  // True when the client can negotiate the fare (not fixed or hourly)
  bool get isNegotiable =>
      pricingModel != 'fixed' && pricingModel != 'hourly';

  // True when real-time GPS tracking is needed
  bool get requiresGpsTracking =>
      !TransportTypeConstants.noTrackingSlugs.contains(transportType);

  // Display currency — returned by the backend per zone (EUR, TND, MAD, DZD…)
  String get displayCurrency => currency ?? 'TND';
}

class AssignmentRequest {
  final String serviceId;
  final String? documentUrl;

  AssignmentRequest({
    required this.serviceId,
    this.documentUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'document_url': documentUrl, // Envoyer null explicitement
    };
  }
}

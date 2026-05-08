import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';

// Provider pour récupérer le token depuis SharedPreferences
final tokenProvider = AsyncNotifierProvider<TokenNotifier, String?>(() {
  return TokenNotifier();
});

class TokenNotifier extends AsyncNotifier<String?> {
  @override
  String? build() {
    return null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> refreshToken() async {
    state = const AsyncValue.loading();
    try {
      final token = await getToken();
      state = AsyncValue.data(token);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Provider pour les services
final servicesProvider = StateNotifierProvider<ServicesNotifier, ServicesState>((ref) {
  final prefs = SharedPreferences.getInstance();
  prefs.then((prefs) {
    final token = prefs.getString('access_token') ?? '';
    return ServicesNotifier(token);
  });
  return ServicesNotifier('');
});


// Provider pour le catalogue
final catalogueProvider = AsyncNotifierProvider<CatalogueNotifier, ServiceCatalogue>(() {
  return CatalogueNotifier();
});

class CatalogueNotifier extends AsyncNotifier<ServiceCatalogue> {
  bool _isLoading = false;

  @override
  ServiceCatalogue build() {
    return ServiceCatalogue(data: [], total: 0);
  }

  Future<void> fetchCatalogue() async {
    // Éviter les appels multiples
    if (_isLoading) {
      print('DEBUG: fetchCatalogue - déjà en cours, ignore');
      return;
    }

    _isLoading = true;
    
    // Ne pas effacer les données existantes pendant le chargement
    if (state.value == null || state.value!.data.isEmpty) {
      state = const AsyncValue.loading();
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      print('DEBUG: fetchCatalogue - token: ${token.isEmpty ? 'vide' : 'présent'}');
      
      final catalogue = await ServiceApi.getCatalogue(token: token);
      print('DEBUG: Catalogue récupéré - categories count: ${catalogue.data.length}');
      print('DEBUG: Catalogue récupéré - total: ${catalogue.total}');
      
      state = AsyncValue.data(catalogue);
    } catch (e, stack) {
      print('DEBUG: Erreur fetchCatalogue: $e');
      // Ne pas effacer les données existantes en cas d'erreur
      if (state.value != null && state.value!.data.isNotEmpty) {
        print('DEBUG: Conservation des données existantes malgré l\'erreur');
        // Garder les données existantes mais marquer l'erreur
        return;
      }
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoading = false;
    }
  }
}

// Provider pour les affectations
final assignmentsProvider = StateNotifierProvider<AssignmentsNotifier, AssignmentsState>((ref) {
  final prefs = SharedPreferences.getInstance();
  prefs.then((prefs) {
    final token = prefs.getString('access_token') ?? '';
    return AssignmentsNotifier(token);
  });
  return AssignmentsNotifier('');
});

// Provider pour l'affectation actuelle
final currentAssignmentProvider = AsyncNotifierProvider<CurrentAssignmentNotifier, ServiceAssignment?>(() {
  return CurrentAssignmentNotifier();
});

class CurrentAssignmentNotifier extends AsyncNotifier<ServiceAssignment?> {
  @override
  ServiceAssignment? build() {
    return null;
  }

  Future<void> fetchCurrentAssignment() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final assignment = await ServiceApi.getCurrentAssignment(token: token);
      state = AsyncValue.data(assignment);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

class ServicesState {
  final List<Service> services;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? selectedCategory;
  final String? selectedTransportType;
  final String? selectedPricingModel;
  final List<ServiceCategory> categories;
  final String? error;

  ServicesState({
    this.services = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.selectedCategory,
    this.selectedTransportType,
    this.selectedPricingModel,
    this.categories = const [],
    this.error,
  });

  ServicesState copyWith({
    List<Service>? services,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? selectedCategory,
    String? selectedTransportType,
    String? selectedPricingModel,
    List<ServiceCategory>? categories,
    String? error,
  }) {
    return ServicesState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedTransportType: selectedTransportType ?? this.selectedTransportType,
      selectedPricingModel: selectedPricingModel ?? this.selectedPricingModel,
      categories: categories ?? this.categories,
      error: error,
    );
  }
}

class ServicesNotifier extends StateNotifier<ServicesState> {
  final String _token;
  final List<String> _transportTypes = ['taxi', 'moto', 'livraison', 'van', 'voiture'];
  final List<String> _pricingModels = ['fixed', 'hourly', 'distance', 'commission'];
  bool isInitialized = false;

  ServicesNotifier(this._token) : super(ServicesState()) {
    if (_token.isNotEmpty) {
      _initialize();
    }
    isInitialized = true;
  }

  Future<void> _initialize() async {
    await Future.wait([
      fetchCategories(),
      fetchServices(reset: true),
    ]);
  }

  Future<void> fetchCategories() async {
    try {
      final categories = await ServiceApi.getCategories(token: _token);
      state = state.copyWith(categories: categories);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> fetchServices({bool reset = false}) async {
    print('DEBUG: fetchServices appelé - token: ${_token.isNotEmpty ? "présent" : "vide"}');
    print('DEBUG: fetchServices - reset: $reset, isLoading: ${state.isLoading}, hasMore: ${state.hasMore}');
    
    if (state.isLoading) return;
    if (!state.hasMore && !reset) return;

    final page = reset ? 1 : state.currentPage;
    
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: page,
      services: reset ? [] : state.services,
    );

    try {
      print('DEBUG: Appel API ServiceApi.getServices...');
      final response = await ServiceApi.getServices(
        token: _token,
        page: page,
        limit: 10,
        categoryId: state.selectedCategory,
        transportType: state.selectedTransportType,
        pricingModel: state.selectedPricingModel,
      );
      
      print('DEBUG: API réponse reçue - services count: ${response.data.length}');
      print('DEBUG: API réponse - hasNextPage: ${response.meta.hasNextPage}');

      final newServices = reset 
          ? response.data 
          : [...state.services, ...response.data];

      state = state.copyWith(
        services: newServices,
        isLoading: false,
        hasMore: response.meta.hasNextPage,
        currentPage: page + 1,
      );
      
      print('DEBUG: État mis à jour - services count: ${state.services.length}');
    } catch (e) {
      print('DEBUG: Erreur API fetchServices: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCategoryFilter(String? categoryId) {
    if (state.selectedCategory != categoryId) {
      state = state.copyWith(selectedCategory: categoryId);
      fetchServices(reset: true);
    }
  }

  void setTransportTypeFilter(String? transportType) {
    if (state.selectedTransportType != transportType) {
      state = state.copyWith(selectedTransportType: transportType);
      fetchServices(reset: true);
    }
  }

  void setPricingModelFilter(String? pricingModel) {
    if (state.selectedPricingModel != pricingModel) {
      state = state.copyWith(selectedPricingModel: pricingModel);
      fetchServices(reset: true);
    }
  }

  void clearFilters() {
    state = state.copyWith(
      selectedCategory: null,
      selectedTransportType: null,
      selectedPricingModel: null,
    );
    fetchServices(reset: true);
  }

  Future<void> refresh() async {
    await fetchServices(reset: true);
  }

  List<String> get transportTypes => _transportTypes;
  List<String> get pricingModels => _pricingModels;
}

class AssignmentsState {
  final List<ServiceAssignment> assignments;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  AssignmentsState({
    this.assignments = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  AssignmentsState copyWith({
    List<ServiceAssignment>? assignments,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return AssignmentsState(
      assignments: assignments ?? this.assignments,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class AssignmentsNotifier extends StateNotifier<AssignmentsState> {
  final String _token;

  AssignmentsNotifier(this._token) : super(AssignmentsState()) {
    if (_token.isNotEmpty) {
      fetchAssignments(reset: true);
    }
  }

  Future<void> fetchAssignments({bool reset = false}) async {
    if (state.isLoading) return;
    if (!state.hasMore && !reset) return;

    final page = reset ? 1 : state.currentPage;
    
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: page,
      assignments: reset ? [] : state.assignments,
    );

    try {
      final response = await ServiceApi.getMyAssignments(
        token: _token,
        page: page,
        limit: 10,
      );

      final newAssignments = reset 
          ? response.data 
          : [...state.assignments, ...response.data];

      state = state.copyWith(
        assignments: newAssignments,
        isLoading: false,
        hasMore: response.meta.hasNextPage,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await fetchAssignments(reset: true);
  }

  Future<void> cancelAssignment(String assignmentId) async {
    try {
      await ServiceApi.cancelAssignment(
        token: _token,
        assignmentId: assignmentId,
      );

      state = state.copyWith(
        assignments: state.assignments
            .where((assignment) => assignment.id != assignmentId)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

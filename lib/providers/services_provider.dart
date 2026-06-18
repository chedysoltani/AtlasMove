import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';

// Provider pour récupérer le token depuis le stockage sécurisé
final tokenProvider = AsyncNotifierProvider<TokenNotifier, String?>(() {
  return TokenNotifier();
});

class TokenNotifier extends AsyncNotifier<String?> {
  @override
  String? build() {
    return null;
  }

  Future<String?> getToken() => TokenStorage.getAccessToken();

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
  return ServicesNotifier();
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

  Future<void> fetchCatalogue({double? latitude, double? longitude}) async {
    if (_isLoading) return;
    _isLoading = true;

    if (state.value == null || state.value!.data.isEmpty) {
      state = const AsyncValue.loading();
    }

    try {
      final catalogue = await _fetchWithFallback(latitude: latitude, longitude: longitude);
      state = AsyncValue.data(catalogue);
    } catch (e, stack) {
      if (state.value != null && state.value!.data.isNotEmpty) return;
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoading = false;
    }
  }

  Future<ServiceCatalogue> _fetchWithFallback({double? latitude, double? longitude}) async {
    final params = <String, dynamic>{};
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    final q = params.isEmpty ? null : params;

    for (final path in ['/services/catalogue', '/services']) {
      try {
        final response = await HttpClient.get(path, queryParams: q);
        if (response.isSuccess) {
          return ServiceCatalogue.fromJson(response.json);
        }
      } catch (_) {
        continue;
      }
    }

    final token = await TokenStorage.getAccessToken();
    return ServiceApi.getCatalogue(token: token, latitude: latitude, longitude: longitude);
  }
}

// Provider pour les affectations
final assignmentsProvider = StateNotifierProvider<AssignmentsNotifier, AssignmentsState>((ref) {
  return AssignmentsNotifier();
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
      final token = await TokenStorage.getAccessToken() ?? '';
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
  final List<String> _transportTypes = ['taxi', 'moto', 'livraison', 'van', 'voiture'];
  final List<String> _pricingModels = ['fixed', 'hourly', 'distance', 'commission'];

  ServicesNotifier() : super(ServicesState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      fetchCategories(),
      fetchServices(reset: true),
    ]);
  }

  Future<void> fetchCategories() async {
    try {
      final token = await TokenStorage.getAccessToken() ?? '';
      final categories = await ServiceApi.getCategories(token: token);
      state = state.copyWith(categories: categories);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> fetchServices({bool reset = false}) async {
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
      final token = await TokenStorage.getAccessToken() ?? '';
      final response = await ServiceApi.getServices(
        token: token,
        page: page,
        limit: 10,
        categoryId: state.selectedCategory,
        transportType: state.selectedTransportType,
        pricingModel: state.selectedPricingModel,
      );

      final newServices = reset
          ? response.data
          : [...state.services, ...response.data];

      state = state.copyWith(
        services: newServices,
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
  AssignmentsNotifier() : super(AssignmentsState()) {
    fetchAssignments(reset: true);
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
      final token = await TokenStorage.getAccessToken() ?? '';
      final response = await ServiceApi.getMyAssignments(
        token: token,
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
      final token = await TokenStorage.getAccessToken() ?? '';
      await ServiceApi.cancelAssignment(
        token: token,
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

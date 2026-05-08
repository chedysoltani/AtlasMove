import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';

class AssignmentsState {
  final List<ServiceAssignment> history;
  final ServiceAssignment? currentAssignment;
  final bool isLoading;
  final bool isLoadingCurrent;
  final String? error;

  AssignmentsState({
    this.history = const [],
    this.currentAssignment,
    this.isLoading = false,
    this.isLoadingCurrent = false,
    this.error,
  });

  AssignmentsState copyWith({
    List<ServiceAssignment>? history,
    ServiceAssignment? currentAssignment,
    bool? isLoading,
    bool? isLoadingCurrent,
    String? error,
  }) {
    return AssignmentsState(
      history: history ?? this.history,
      currentAssignment: currentAssignment ?? this.currentAssignment,
      isLoading: isLoading ?? this.isLoading,
      isLoadingCurrent: isLoadingCurrent ?? this.isLoadingCurrent,
      error: error,
    );
  }
}

class AssignmentsNotifier extends StateNotifier<AssignmentsState> {
  String _token = '';

  AssignmentsNotifier() : super(AssignmentsState());

  Future<void> _initializeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token') ?? '';
      print('DEBUG: ASSIGNMENTS - Token initialisé: ${_token.isNotEmpty ? "présent" : "vide"}');
    } catch (e) {
      print('DEBUG: ASSIGNMENTS - Erreur initialisation token: $e');
      _token = '';
    }
  }

  Future<void> loadAssignmentsHistory() async {
    if (_token.isEmpty) await _initializeToken();
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final history = await ServiceApi.getAssignmentsHistory(token: _token);
      state = state.copyWith(
        history: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadCurrentAssignment() async {
    if (_token.isEmpty) await _initializeToken();
    
    state = state.copyWith(isLoadingCurrent: true, error: null);
    
    try {
      final currentAssignment = await ServiceApi.getCurrentAssignment(token: _token);
      state = state.copyWith(
        currentAssignment: currentAssignment,
        isLoadingCurrent: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCurrent: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadAssignmentsHistory(),
      loadCurrentAssignment(),
    ]);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider pour les assignements
final assignmentsProvider = StateNotifierProvider<AssignmentsNotifier, AssignmentsState>((ref) {
  return AssignmentsNotifier();
});

// Provider pour forcer le rechargement
final assignmentsRefreshProvider = FutureProvider<void>((ref) async {
  final notifier = ref.read(assignmentsProvider.notifier);
  await notifier.refreshAll();
});

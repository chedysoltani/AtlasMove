import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/auth_request.dart';
import '../services/profile_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _token;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  String? get token => _token;

  // Méthodes pour mettre à jour l'utilisateur et le token
  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // Login - Supprimé car nous utilisons AuthService.login() qui retourne les vraies données de l'API
  // Future<bool> login(String email, String password, UserRole role) async {
  //   // Cette méthode est supprimée car nous utilisons les vraies données de l'API via AuthService
  // }

  // Signup
  Future<bool> signup(SignupRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      // Simuler un appel API
      await Future.delayed(const Duration(seconds: 3));

      // Créer un utilisateur fictif pour la démo
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        firstName: request.firstName,
        lastName: request.lastName,
        email: request.email,
        phone: request.phone,
        role: request.role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vehicleType: request.vehicleType,
        cinImage: request.cinImage,
        carteGriseImage: request.carteGriseImage,
        permisImage: request.permisImage,
        isVerified: request.role == UserRole.delivery,
        isAvailable: request.role == UserRole.delivery,
      );

      _currentUser = user;
      _token = 'demo_token_${user.id}'; // Token simulé pour la démo
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Erreur d\'inscription: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    _clearError();
    try {
      // Arrêt des services + suppression du token + flag explicit_logout
      await ProfileService.logout();
      _currentUser = null;
      _token = null;
    } catch (e) {
      debugPrint('Erreur de déconnexion: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      // Simuler un appel API
      await Future.delayed(const Duration(seconds: 1));

      // Mettre à jour l'utilisateur
      _currentUser = _currentUser!.copyWith(
        updatedAt: DateTime.now(),
        // TODO: Appliquer les mises à jour selon les champs
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Erreur de mise à jour: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Toggle availability for delivery users
  Future<bool> toggleAvailability() async {
    if (_currentUser == null || _currentUser!.role != UserRole.delivery) {
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Simuler un appel API
      await Future.delayed(const Duration(milliseconds: 500));

      _currentUser = _currentUser!.copyWith(
        isAvailable: !_currentUser!.isAvailable,
        updatedAt: DateTime.now(),
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Erreur de mise à jour: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Check if user is delivery
  bool get isDeliveryUser => _currentUser?.role == UserRole.delivery;

  // Check if user is client
  bool get isClientUser => _currentUser?.role == UserRole.client;
}

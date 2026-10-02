import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/utils/permission_gate.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // État de la localisation
  Position? _currentPosition;
  bool _isLocationEnabled = false;
  Stream<Position>? _positionStream;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;
  Stream<Position>? get positionStream => _positionStream;

  /// Vérifier si le service de localisation est activé
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Demander les permissions de localisation
  Future<LocationPermission> requestLocationPermission() async {
    // Vérifier d'abord si la permission est déjà accordée
    var status = await Permission.location.status;
    
    if (status.isGranted) {
      return LocationPermission.whileInUse;
    }

    // Demander la permission
    status = await PermissionGate.run(Permission.location.request, onTimeout: PermissionStatus.denied);
    
    if (status.isGranted) {
      return LocationPermission.whileInUse;
    } else if (status.isDenied) {
      return LocationPermission.denied;
    } else if (status.isPermanentlyDenied) {
      return LocationPermission.deniedForever;
    }
    
    return LocationPermission.unableToDetermine;
  }

  /// Statut actuel de la permission « toujours » (arrière-plan). Sur Android
  /// et iOS, elle ne peut être obtenue qu'APRÈS que « pendant l'utilisation »
  /// a déjà été accordée — sinon le système l'ignore silencieusement.
  Future<PermissionStatus> backgroundPermissionStatus() =>
      Permission.locationAlways.status;

  /// Demande la permission « toujours ». À appeler uniquement après un écran
  /// expliquant pourquoi (Play Store / App Store l'exigent), et seulement pour
  /// les chauffeurs (le suivi pendant une course doit continuer app fermée).
  Future<PermissionStatus> requestBackgroundLocationPermission() async {
    final whileInUse = await Permission.location.status;
    if (!whileInUse.isGranted) {
      // Étape obligatoire côté OS : on ne peut pas sauter directement à "toujours".
      await PermissionGate.run(Permission.location.request, onTimeout: PermissionStatus.denied);
    }
    return PermissionGate.run(Permission.locationAlways.request, onTimeout: PermissionStatus.denied);
  }

  /// Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('DEBUG: Service de localisation désactivé');
        return null;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await PermissionGate.run(Geolocator.requestPermission, onTimeout: LocationPermission.denied);
        if (permission == LocationPermission.denied) {
          print('DEBUG: Permission de localisation refusée');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('DEBUG: Permission de localisation refusée définitivement');
        return null;
      }

      // Obtenir la position actuelle
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Changé à medium pour plus de fiabilité
        timeLimit: const Duration(seconds: 30), // Augmenté à 30 secondes
      );

      _currentPosition = position;
      _isLocationEnabled = true;
      
      print('DEBUG: Position actuelle obtenue: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      print('DEBUG: Erreur lors de l\'obtention de la position: $e');
      
      // Pour l'émulateur, retourner une position par défaut si le GPS n'est pas disponible
      if (e.toString().contains('Timeout') || e.toString().contains('Location service is disabled')) {
        print('DEBUG: Utilisation de la position par défaut pour l\'émulateur');
        final defaultPosition = Position(
          latitude: 33.5731,  // Casablanca
          longitude: -7.5898,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        
        _currentPosition = defaultPosition;
        _isLocationEnabled = true;
        return defaultPosition;
      }
      
      return null;
    }
  }

  /// Démarrer le suivi de la position en continu
  Future<void> startLocationUpdates() async {
    try {
      // Vérifier si le service est activé
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('DEBUG: Service de localisation désactivé');
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await PermissionGate.run(Geolocator.requestPermission, onTimeout: LocationPermission.denied);
        if (permission != LocationPermission.whileInUse && 
            permission != LocationPermission.always) {
          print('DEBUG: Permission de localisation non accordée');
          return;
        }
      }

      // Configuration de la localisation
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mettre à jour tous les 10 mètres
      );

      // Démarrer le stream
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings);
      _isLocationEnabled = true;

      print('DEBUG: Suivi de localisation démarré');
    } catch (e) {
      print('DEBUG: Erreur lors du démarrage du suivi: $e');
    }
  }

  /// Arrêter le suivi de la position
  void stopLocationUpdates() {
    _positionStream = null;
    _isLocationEnabled = false;
    print('DEBUG: Suivi de localisation arrêté');
  }

  /// Ouvrir les paramètres de l'application
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Ouvrir les paramètres de localisation du système
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Calculer la distance entre deux points en mètres
  double calculateDistance(double startLatitude, double startLongitude, 
                          double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
      startLatitude, startLongitude, endLatitude, endLongitude,
    );
  }

  /// Convertir Position en LatLng pour Google Maps
  LatLng? positionToLatLng(Position? position) {
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  /// Vérifier si la position est dans une zone définie
  bool isPositionInBounds(LatLng position, LatLngBounds bounds) {
    return bounds.contains(position);
  }

  /// Nettoyer les ressources
  void dispose() {
    stopLocationUpdates();
    _currentPosition = null;
  }
}

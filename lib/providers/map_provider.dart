import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

// État de la carte
enum MapStatus {
  initial,
  loading,
  ready,
  error,
  permissionDenied,
  locationDisabled,
}

class MapState {
  final MapStatus status;
  final LatLng? currentPosition;
  final GoogleMapController? mapController;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final CameraPosition? cameraPosition;
  final String? errorMessage;
  final bool isFollowingUser;

  const MapState({
    this.status = MapStatus.initial,
    this.currentPosition,
    this.mapController,
    this.markers = const {},
    this.polylines = const {},
    this.cameraPosition,
    this.errorMessage,
    this.isFollowingUser = true,
  });

  MapState copyWith({
    MapStatus? status,
    LatLng? currentPosition,
    GoogleMapController? mapController,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    CameraPosition? cameraPosition,
    String? errorMessage,
    bool? isFollowingUser,
  }) {
    return MapState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      mapController: mapController ?? this.mapController,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      cameraPosition: cameraPosition ?? this.cameraPosition,
      errorMessage: errorMessage ?? this.errorMessage,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapState &&
        other.status == status &&
        other.currentPosition == currentPosition &&
        other.mapController == mapController &&
        other.markers == markers &&
        other.polylines == polylines &&
        other.cameraPosition == cameraPosition &&
        other.errorMessage == errorMessage &&
        other.isFollowingUser == isFollowingUser;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        currentPosition.hashCode ^
        mapController.hashCode ^
        markers.hashCode ^
        polylines.hashCode ^
        cameraPosition.hashCode ^
        errorMessage.hashCode ^
        isFollowingUser.hashCode;
  }
}

class MapNotifier extends StateNotifier<MapState> {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _positionSub;

  MapNotifier() : super(const MapState());

  /// Initialiser la carte et obtenir la position
  Future<void> initializeMap() async {
    state = state.copyWith(status: MapStatus.loading);

    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          status: MapStatus.locationDisabled,
          errorMessage: 'Le service de localisation est désactivé. Veuillez l\'activer.',
        );
        return;
      }

      // Demander les permissions
      LocationPermission permission = await _locationService.requestLocationPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          status: MapStatus.permissionDenied,
          errorMessage: 'Permission de localisation refusée. Veuillez l\'accorder.',
        );
        return;
      } else if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          status: MapStatus.permissionDenied,
          errorMessage: 'Permission de localisation refusée définitivement. Veuillez l\'accorder dans les paramètres.',
        );
        return;
      }

      // Obtenir la position actuelle
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        state = state.copyWith(
          status: MapStatus.error,
          errorMessage: 'Impossible d\'obtenir votre position actuelle.',
        );
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);
      
      // Créer le marker pour la position actuelle
      final userMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Votre position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      final initialCameraPosition = CameraPosition(
        target: latLng,
        zoom: 15,
      );

      state = state.copyWith(
        status: MapStatus.ready,
        currentPosition: latLng,
        markers: {userMarker},
        cameraPosition: initialCameraPosition,
        errorMessage: null,
      );

      // Démarrer le suivi de la position
      await _startLocationTracking();

    } catch (e) {
      state = state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Erreur lors de l\'initialisation de la carte: ${e.toString()}',
      );
    }
  }

  /// Démarrer le suivi de la position
  Future<void> _startLocationTracking() async {
    await _positionSub?.cancel();
    await _locationService.startLocationUpdates();

    _positionSub = _locationService.positionStream?.listen((Position position) {
      final latLng = LatLng(position.latitude, position.longitude);

      final userMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Votre position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      state = state.copyWith(
        currentPosition: latLng,
        markers: {...state.markers.where((m) => m.markerId.value != 'current_position'), userMarker},
      );

      // Follow user but preserve current zoom level instead of hardcoding 15
      if (state.isFollowingUser && state.mapController != null) {
        state.mapController?.animateCamera(
          CameraUpdate.newLatLng(latLng),
        );
      }
    });
  }

  /// Définir le contrôleur de la carte
  void setMapController(GoogleMapController controller) {
    state = state.copyWith(mapController: controller);
  }

  /// Centrer la caméra sur la position actuelle
  Future<void> centerOnCurrentPosition() async {
    if (state.currentPosition != null && state.mapController != null) {
      await state.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: state.currentPosition!,
            zoom: 15,
          ),
        ),
      );
    }
  }

  /// Activer/Désactiver le suivi de la position
  void toggleFollowingUser() {
    state = state.copyWith(isFollowingUser: !state.isFollowingUser);
  }

  /// Ajouter un marker
  void addMarker(Marker marker) {
    state = state.copyWith(
      markers: {...state.markers, marker},
    );
  }

  /// Supprimer un marker
  void removeMarker(String markerId) {
    state = state.copyWith(
      markers: state.markers.where((m) => m.markerId.value != markerId).toSet(),
    );
  }

  /// Ajouter une polyline
  void addPolyline(Polyline polyline) {
    state = state.copyWith(
      polylines: {...state.polylines, polyline},
    );
  }

  /// Supprimer toutes les polylines
  void clearPolylines() {
    state = state.copyWith(polylines: {});
  }

  /// Réinitialiser la carte
  void resetMap() {
    state = const MapState();
  }

  /// Réessayer l'initialisation
  Future<void> retry() async {
    await initializeMap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

// Provider pour la carte
final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});

// Provider pour le contrôleur de la carte
final mapControllerProvider = Provider<GoogleMapController?>((ref) {
  return ref.watch(mapProvider).mapController;
});

import 'dart:async';
import 'dart:ui' show Offset;
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
  // ✅ RETIRÉ: mapController ne doit PAS être dans l'état immutable
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final CameraPosition? cameraPosition;
  final String? errorMessage;
  final bool isFollowingUser;

  const MapState({
    this.status = MapStatus.initial,
    this.currentPosition,
    this.markers = const {},
    this.polylines = const {},
    this.cameraPosition,
    this.errorMessage,
    this.isFollowingUser = true,
  });

  MapState copyWith({
    MapStatus? status,
    LatLng? currentPosition,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    CameraPosition? cameraPosition,
    String? errorMessage,
    bool? isFollowingUser,
  }) {
    return MapState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
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
  GoogleMapController? _mapController;
  Position? _lastPosition;

  // Options de la dernière initialisation (voir initializeMap).
  bool _showUserMarker = true;
  bool _autoFollowCamera = true;

  /// Expose the live controller without polluting immutable MapState.
  GoogleMapController? get mapController => _mapController;

  /// Dernière position GPS complète (cap, vitesse, précision) — MapState ne
  /// garde que le LatLng.
  Position? get lastPosition => _lastPosition;

  MapNotifier() : super(const MapState());

  /// Initialiser la carte et obtenir la position.
  ///
  /// [showUserMarker] : ajoute le marqueur bleu 'current_position'. À passer à
  /// `false` sur les écrans qui affichent leur propre marqueur chauffeur, sinon
  /// deux marqueurs représentent la même position.
  /// [autoFollowCamera] : le notifier recentre lui-même la caméra à chaque
  /// position. À passer à `false` quand l'écran pilote la caméra (sinon deux
  /// animateCamera se disputent).
  Future<void> initializeMap({
    bool showUserMarker = true,
    bool autoFollowCamera = true,
  }) async {
    _showUserMarker = showUserMarker;
    _autoFollowCamera = autoFollowCamera;
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

      _lastPosition = position;
      final latLng = LatLng(position.latitude, position.longitude);

      final initialCameraPosition = CameraPosition(
        target: latLng,
        zoom: 15,
      );

      state = state.copyWith(
        status: MapStatus.ready,
        currentPosition: latLng,
        // Repart d'un état propre : ce provider est global, les marqueurs d'un
        // écran précédent ne doivent pas survivre.
        markers: _showUserMarker ? {_userMarker(latLng)} : <Marker>{},
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
      _lastPosition = position;
      final latLng = LatLng(position.latitude, position.longitude);

      state = state.copyWith(
        currentPosition: latLng,
        markers: _showUserMarker
            ? _replaceMarker(state.markers, _userMarker(latLng))
            : state.markers,
      );

      // Follow user but preserve current zoom level instead of hardcoding 15
      if (_autoFollowCamera && state.isFollowingUser && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(latLng),
        );
      }
    });
  }

  BitmapDescriptor? _userIcon;

  /// Icône personnalisée du marqueur « vous êtes ici » (sinon pin bleu par défaut).
  void setUserMarkerIcon(BitmapDescriptor icon) {
    _userIcon = icon;
    final pos = state.currentPosition;
    if (_showUserMarker && pos != null) {
      state = state.copyWith(markers: _replaceMarker(state.markers, _userMarker(pos)));
    }
  }

  Marker _userMarker(LatLng position) => Marker(
        markerId: const MarkerId('current_position'),
        position: position,
        infoWindow: const InfoWindow(title: 'Votre position'),
        icon: _userIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: _userIcon != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
      );

  /// `Marker.==` compare TOUS les champs (position, rotation, icône…) alors que
  /// `hashCode` ne dépend que du markerId : un `{...set, marker}` avec le même
  /// id mais une autre position ajoute un doublon dans le Set au lieu de
  /// remplacer. On remplace donc explicitement par id.
  static Set<Marker> _replaceMarker(Set<Marker> markers, Marker marker) => {
        for (final m in markers)
          if (m.markerId != marker.markerId) m,
        marker,
      };

  /// Arrête le suivi GPS et détache la carte. À appeler dans le `dispose()` de
  /// l'écran : ce provider est global, sans cela le flux GPS haute précision
  /// continue de tourner (et d'animer un contrôleur détruit) après la sortie
  /// de l'écran.
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _mapController = null;
  }

  /// Définir le contrôleur de la carte
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Centrer la caméra sur la position actuelle
  Future<void> centerOnCurrentPosition() async {
    if (state.currentPosition != null && _mapController != null) {
      await _mapController!.animateCamera(
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
      markers: _replaceMarker(state.markers, marker),
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
    _mapController = null;
    _locationService.dispose();
    super.dispose();
  }
}

// Provider pour la carte
final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});

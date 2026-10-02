import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/notification_service.dart';
import '../services/trip_service.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum RideStatus { accepted, arriving, arrived, inProgress, completed, cancelled, unknown }

class DriverLocation {
  final LatLng position;
  final double? heading;
  final double? speed; // m/s
  final double? accuracy; // m
  final DateTime updatedAt;

  const DriverLocation({
    required this.position,
    this.heading,
    this.speed,
    this.accuracy,
    required this.updatedAt,
  });

  bool get isStale => DateTime.now().difference(updatedAt).inSeconds > 15;
}

class ActiveRideState {
  final String? tripId;
  final RideStatus status;
  final DriverLocation? driverLocation;

  const ActiveRideState({
    this.tripId,
    this.status = RideStatus.unknown,
    this.driverLocation,
  });

  bool get isActive =>
      status != RideStatus.completed && status != RideStatus.cancelled;

  ActiveRideState copyWith({
    String? tripId,
    RideStatus? status,
    DriverLocation? driverLocation,
    bool clearDriverLocation = false,
  }) {
    return ActiveRideState(
      tripId: tripId ?? this.tripId,
      status: status ?? this.status,
      driverLocation:
          clearDriverLocation ? null : (driverLocation ?? this.driverLocation),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class RideStateNotifier extends StateNotifier<ActiveRideState> {
  Timer? _pollTimer;
  Timer? _stallTimer;

  RideStateNotifier() : super(const ActiveRideState());

  // ── Public API ──────────────────────────────────────────────────────────────

  void startForTrip(String tripId, String initialStatus) {
    _cancelTimers();
    state = ActiveRideState(
      tripId: tripId,
      status: _parse(initialStatus),
    );

    // Wire WebSocket push callbacks
    NotificationService.onDriverLocationReceived = _onWsDriverLocation;
    NotificationService.onTripStatusReceived = _onWsTripStatus;
    NotificationService.onTripCancelledReceived = _onWsTripStatus;

    // Fallback REST poll — fires when WebSocket is silent or disconnected
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll(tripId));
  }

  void stopTracking() {
    _cancelTimers();
    NotificationService.onDriverLocationReceived = null;
    NotificationService.onTripStatusReceived = null;
    NotificationService.onTripCancelledReceived = null;
    state = const ActiveRideState();
  }

  // ── WebSocket handlers ──────────────────────────────────────────────────────

  void _onWsDriverLocation(Map<String, dynamic> data) {
    // Unwrap { data: {...} } envelope emitted by some backend versions
    final p = (data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;

    // Le backend inclut TOUJOURS tripId : un évènement sans tripId, ou pour une
    // autre course, n'est jamais affiché (le client ne doit voir que SON chauffeur).
    final eventTripId = (p['tripId'] ?? p['trip_id'])?.toString();
    if (eventTripId == null || eventTripId != state.tripId) return;

    // Accept both latitude/longitude and lat/lng
    final lat = ((p['latitude'] ?? p['lat']) as num?)?.toDouble();
    final lng = ((p['longitude'] ?? p['lng']) as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _resetStallTimer();
    if (!mounted) return;
    state = state.copyWith(
      driverLocation: DriverLocation(
        position: LatLng(lat, lng),
        heading: (p['heading'] as num?)?.toDouble(),
        speed: (p['speed'] as num?)?.toDouble(),
        accuracy: (p['accuracy'] as num?)?.toDouble(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _onWsTripStatus(Map<String, dynamic> data) {
    // Unwrap { data: {...} } envelope
    final p = (data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;

    final eventTripId = p['tripId'] as String? ?? p['trip_id'] as String?;
    if (eventTripId != null && eventTripId != state.tripId) return;

    final newStatus = _parse(p['status'] as String? ?? data['status'] as String? ?? '');
    if (newStatus == state.status || !mounted) return;
    state = state.copyWith(status: newStatus);
  }

  // ── Fallback REST poll ──────────────────────────────────────────────────────

  Future<void> _poll(String tripId) async {
    // Stop polling for terminal states
    if (state.status == RideStatus.completed || state.status == RideStatus.cancelled) {
      _cancelTimers();
      return;
    }
    // Only hit REST when WebSocket is down OR driver location has gone stale
    final wsUp = NotificationService().isConnected;
    final locationFresh = !(state.driverLocation?.isStale ?? true);
    if (wsUp && locationFresh) return;

    try {
      // Fetch driver location. 404 driver_location_unavailable → null : on continue
      // de sonder. 409 trip_not_active → la course est finie : on ARRÊTE de sonder.
      var tripOver = false;
      DriverLocationDto? loc;
      try {
        loc = await TripService.getDriverLocation(tripId);
      } on TripNotActiveException {
        tripOver = true;
      }
      if (loc != null && mounted) {
        _resetStallTimer();
        state = state.copyWith(
          driverLocation: DriverLocation(
            position: LatLng(loc.latitude, loc.longitude),
            heading: loc.heading,
            speed: loc.speed,
            accuracy: loc.accuracy,
            updatedAt: DateTime.now(),
          ),
        );
      }

      // Fetch trip status via client endpoint (avoids calling /l/trips/active with client token)
      final statusStr = await TripService.getClientTripStatus(tripId);
      if (statusStr != null && mounted) {
        final newStatus = _parse(statusStr);
        if (newStatus != state.status) {
          state = state.copyWith(status: newStatus);
        }
      }

      if (tripOver) _cancelTimers(); // statut final lu ci-dessus, plus rien à sonder
    } catch (_) {}
  }

  // ── Stale-location detection ────────────────────────────────────────────────

  void _resetStallTimer() {
    _stallTimer?.cancel();
    // After 15 s with no update, consumers re-check driverLocation.isStale
    _stallTimer = Timer(const Duration(seconds: 15), () {
      if (mounted &&
          state.status != RideStatus.completed &&
          state.status != RideStatus.cancelled) {
        state = state.copyWith(); // force rebuild so UI re-evaluates isStale
      }
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static RideStatus _parse(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':    return RideStatus.accepted;
      case 'arriving':
      case 'livreur_en_route': return RideStatus.arriving;
      case 'arrived':     return RideStatus.arrived;
      case 'in_progress': return RideStatus.inProgress;
      case 'completed':   return RideStatus.completed;
      case 'cancelled':
      case 'cancelled_by_client':
      case 'cancelled_by_livreur':
      case 'cancelled_by_admin':  return RideStatus.cancelled;
      case 'expired':             return RideStatus.cancelled;
      default:                    return RideStatus.unknown;
    }
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _stallTimer?.cancel();
    _pollTimer = null;
    _stallTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    NotificationService.onDriverLocationReceived = null;
    NotificationService.onTripStatusReceived = null;
    NotificationService.onTripCancelledReceived = null;
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final activeRideProvider =
    StateNotifierProvider<RideStateNotifier, ActiveRideState>((ref) {
  return RideStateNotifier();
});

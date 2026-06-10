import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/network/http_client.dart';
import 'location_service.dart';

// Callback déclenché quand le backend détecte une vitesse anormale (anti-spoofing)
typedef OnGpsSpoofingDetected = void Function();

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final LocationService _locationService = LocationService();

  static const _sendInterval     = Duration(seconds: 5);
  static const _heartbeatInterval = Duration(seconds: 10);

  bool _isTracking = false;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  DateTime? _lastSentAt;

  OnGpsSpoofingDetected? onGpsSpoofingDetected;

  bool get isTracking => _isTracking;

  // token param kept for API compatibility but ignored — HttpClient handles auth + refresh
  Future<void> startLocationTracking([String? token]) async {
    if (_isTracking) return;
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) await _sendLocation(position);
      await _startTracking();
      _isTracking = true;
    } catch (e) {
      _isTracking = false;
    }
  }

  Future<void> _startTracking() async {
    await _positionSub?.cancel();
    _heartbeatTimer?.cancel();

    await _locationService.startLocationUpdates();

    _positionSub = _locationService.positionStream?.listen(
      (Position position) async {
        final now = DateTime.now();
        if (_lastSentAt != null && now.difference(_lastSentAt!) < _sendInterval) return;
        await _sendLocation(position);
      },
      onError: (_) {},
    );

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!_isTracking) return;
      final position = await _locationService.getCurrentPosition();
      if (position != null) await _sendLocation(position);
    });
  }

  void stopLocationTracking() {
    if (!_isTracking) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _locationService.stopLocationUpdates();
    _isTracking = false;
    _lastSentAt = null;
  }

  Future<bool> _sendLocation(Position position) async {
    try {
      final response = await HttpClient.post('/trips/location', body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
      });

      if (response.isSuccess) {
        _lastSentAt = DateTime.now();
        return true;
      }

      // 400 = anti-spoofing détecté par le backend
      if (response.statusCode == 400) {
        onGpsSpoofingDetected?.call();
      }

      return false;
    } catch (e) {
      debugPrint('LocationTrackingService: $e');
      return false;
    }
  }

  Future<bool> sendCurrentLocation([String? token]) async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;
    return _sendLocation(position);
  }

  Future<bool> isLocationServiceAvailable() async {
    try {
      final enabled = await _locationService.isLocationServiceEnabled();
      if (!enabled) return false;
      final permission = await _locationService.requestLocationPermission();
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  void dispose() => stopLocationTracking();
}

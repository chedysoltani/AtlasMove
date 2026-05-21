import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final LocationService _locationService = LocationService();
  final String _baseUrl = 'https://api.atla.business/api/v1/l/trips/location';

  // Minimum interval between API sends: 4 seconds
  static const _minSendInterval = Duration(seconds: 4);
  // Heartbeat: send at least once every 8 seconds even without movement
  static const _heartbeatInterval = Duration(seconds: 8);

  bool _isTracking = false;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  DateTime? _lastSentAt;
  Position? _lastSentPosition;

  // Getters
  bool get isTracking => _isTracking;

  /// Start tracking and sending location to API
  Future<void> startLocationTracking(String token) async {
    if (_isTracking) return;

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendLocationToApi(position, token);
      }

      await _startTracking(token);
      _isTracking = true;
    } catch (e) {
      print('DEBUG: Error starting location tracking: $e');
      _isTracking = false;
    }
  }

  Future<void> _startTracking(String token) async {
    await _positionSub?.cancel();
    _heartbeatTimer?.cancel();

    await _locationService.startLocationUpdates();

    // Movement-based: send when moved, but throttle to once per 4 seconds
    _positionSub = _locationService.positionStream?.listen(
      (Position position) async {
        final now = DateTime.now();
        if (_lastSentAt != null &&
            now.difference(_lastSentAt!) < _minSendInterval) {
          return; // too soon — skip this update
        }
        await _sendLocationToApi(position, token);
      },
      onError: (error) => print('DEBUG: position stream error: $error'),
    );

    // Heartbeat: guarantee at least one update every 8 seconds even when stationary
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!_isTracking) return;
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendLocationToApi(position, token);
      }
    });
  }

  /// Stop location tracking
  void stopLocationTracking() {
    if (!_isTracking) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _locationService.stopLocationUpdates();
    _isTracking = false;
    _lastSentAt = null;
    _lastSentPosition = null;
  }

  /// Send location data to API
  Future<bool> _sendLocationToApi(Position position, String token) async {
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    print('DEBUG: Sending location data: $locationData');
    print('DEBUG: Sending to URL: $_baseUrl');

    try {
      final response = await http.patch(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(locationData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: Location API request timeout');
          throw Exception('Request timeout');
        },
      );

      print('DEBUG: API Response Status: ${response.statusCode}');
      print('DEBUG: API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastSentAt = DateTime.now();
        _lastSentPosition = position;
        return true;
      } else {
        print('DEBUG: Failed to send location. Status: ${response.statusCode}');
        print('DEBUG: Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error sending location to API: $e');
      return false;
    }
  }

  /// Get current location and send it once
  Future<bool> sendCurrentLocation(String token) async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        return await _sendLocationToApi(position, token);
      } else {
        print('DEBUG: Unable to get current position');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error getting current location: $e');
      return false;
    }
  }

  /// Check if location service is available
  Future<bool> isLocationServiceAvailable() async {
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('DEBUG: Location service is disabled');
        return false;
      }

      final permission = await _locationService.requestLocationPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('DEBUG: Location permission denied');
        return false;
      }

      return true;
    } catch (e) {
      print('DEBUG: Error checking location service availability: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
  }
}

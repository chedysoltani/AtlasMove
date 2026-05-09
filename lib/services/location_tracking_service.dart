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
  
  bool _isTracking = false;
  Stream<Position>? _positionStream;
  Timer? _periodicTimer;

  // Getters
  bool get isTracking => _isTracking;

  /// Start tracking and sending location to API
  Future<void> startLocationTracking(String token) async {
    if (_isTracking) {
      print('DEBUG: Location tracking already started');
      return;
    }

    print('DEBUG: Starting location tracking with token: ${token.substring(0, 10)}...');
    
    try {
      // Get initial position
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendLocationToApi(position, token);
      }

      // Start continuous tracking with periodic updates
      await _startPeriodicLocationUpdates(token);
      
      _isTracking = true;
      print('DEBUG: Location tracking started successfully (updates every minute)');
    } catch (e) {
      print('DEBUG: Error starting location tracking: $e');
      _isTracking = false;
    }
  }

  /// Start periodic location updates every minute
  Future<void> _startPeriodicLocationUpdates(String token) async {
    print('DEBUG: Starting periodic location updates (every 60 seconds)');
    
    // Use a timer to send location every minute
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        print('DEBUG: Periodic updates stopped');
        return;
      }
      
      try {
        print('DEBUG: === Minute update - Getting current position ===');
        final position = await _locationService.getCurrentPosition();
        
        if (position != null) {
          print('DEBUG: Minute update - Position: ${position.latitude}, ${position.longitude}');
          final success = await _sendLocationToApi(position, token);
          
          if (success) {
            print('DEBUG: Minute update - Location sent successfully');
          } else {
            print('DEBUG: Minute update - Failed to send location');
          }
        } else {
          print('DEBUG: Minute update - Unable to get position');
        }
        
        print('DEBUG: === Next update in 60 seconds ===');
      } catch (e) {
        print('DEBUG: Minute update error: $e');
      }
    });

    // Also listen to movement-based updates for more responsive tracking
    await _locationService.startLocationUpdates();
    _positionStream = _locationService.positionStream;
    
    _positionStream?.listen(
      (Position position) {
        print('DEBUG: Movement-based update: ${position.latitude}, ${position.longitude}');
        // Only send if significant movement (more than 50 meters from last position)
        _sendLocationToApi(position, token);
      },
      onError: (error) {
        print('DEBUG: Error in position stream: $error');
      },
    );
  }

  /// Stop location tracking
  void stopLocationTracking() {
    if (!_isTracking) {
      print('DEBUG: Location tracking not active');
      return;
    }

    // Cancel periodic timer
    _periodicTimer?.cancel();
    _periodicTimer = null;
    
    // Stop location updates
    _locationService.stopLocationUpdates();
    _positionStream = null;
    _isTracking = false;
    
    print('DEBUG: Location tracking stopped (periodic timer cancelled)');
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
        print('DEBUG: Location sent successfully');
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
    _periodicTimer?.cancel();
    _periodicTimer = null;
    stopLocationTracking();
  }
}

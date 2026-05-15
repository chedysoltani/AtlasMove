import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Search result model
class SearchResult {
  final String displayName;
  final LatLng coordinates;
  final double? distance;
  final String? type;
  final String? category;

  SearchResult({
    required this.displayName,
    required this.coordinates,
    this.distance,
    this.type,
    this.category,
  });
}

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // Cache
  static final Map<String, List<SearchResult>> _cache = {};

  // Rate limit
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 500);

  /// Convert address to coordinates
  static Future<LatLng?> getAddressCoordinates(String address) async {
    try {
      await _waitIfNeeded();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?format=json&q=${Uri.encodeComponent(address)}&limit=1',
        ),
        headers: {
          'User-Agent': 'AtlasMove/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: Request timeout');
          return http.Response('Timeout', 408);
        },
      );

      print('DEBUG: getAddressCoordinates status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isNotEmpty) {
          final result = data.first;

          return LatLng(
            double.parse(result['lat']),
            double.parse(result['lon']),
          );
        }
      }

      return null;
    } catch (e) {
      print('ERROR getAddressCoordinates: $e');
      return null;
    }
  }

  /// Convert coordinates to address
  static Future<String?> getAddressFromCoordinates(
    LatLng coordinates,
  ) async {
    try {
      await _waitIfNeeded();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/reverse?format=json'
          '&lat=${coordinates.latitude}'
          '&lon=${coordinates.longitude}',
        ),
        headers: {
          'User-Agent': 'AtlasMove/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: Request timeout');
          return http.Response('Timeout', 408);
        },
      );

      print(
        'DEBUG: getAddressFromCoordinates status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return data['display_name'];
      }

      return null;
    } catch (e) {
      print('ERROR getAddressFromCoordinates: $e');
      return null;
    }
  }

  /// Search real address suggestions with location-based filtering
  static Future<List<String>> searchAddressSuggestions(
    String query, {
    LatLng? userLocation,
    double radiusKm = 50,
  }) async {
    try {
      print('DEBUG: Searching -> "$query" with location: $userLocation');

      // Prevent useless requests
      if (query.trim().length < 2) {
        return [];
      }

      final normalizedQuery = query.trim().toLowerCase();
      final cacheKey = userLocation != null 
          ? '$normalizedQuery|${userLocation.latitude}|${userLocation.longitude}' 
          : normalizedQuery;

      // Cache check
      if (_cache.containsKey(cacheKey)) {
        print('DEBUG: Using cache');
        return _cache[cacheKey]!.map((r) => r.displayName).toList();
      }

      // Try location-based search first
      List<String> results = await _performSearch(query, userLocation, radiusKm);
      
      // Fallback: if no results with location, try without location
      if (results.isEmpty && userLocation != null) {
        print('DEBUG: No results with location, trying fallback search');
        results = await _performSearch(query, null, radiusKm);
      }

      return results;
    } catch (e) {
      print('ERROR searchAddressSuggestions: $e');
      return [];
    }
  }

  /// Perform the actual search
  static Future<List<String>> _performSearch(
    String query,
    LatLng? userLocation,
    double radiusKm,
  ) async {
    try {
      // Wait between requests
      await _waitIfNeeded();

      // Build URL with location parameters
      String url = '$_baseUrl/search'
          '?format=json'
          '&q=${Uri.encodeComponent(query)}'
          '&limit=15'
          '&addressdetails=1'
          '&namedetails=1';

      // Add location bias if available
      if (userLocation != null) {
        url += '&viewbox=${userLocation.longitude - 0.1},${userLocation.latitude + 0.1}'
               '${userLocation.longitude + 0.1},${userLocation.latitude - 0.1}'
               '&bounded=0';
      }

      print('DEBUG: URL -> $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AtlasMove/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: Request timeout');
          return http.Response('Timeout', 408);
        },
      );

      print('DEBUG: Response status -> ${response.statusCode}');

      // Too many requests
      if (response.statusCode == 429) {
        print('DEBUG: RATE LIMITED');
        return [];
      }

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('DEBUG: Results count -> ${data.length}');

        // Convert to SearchResult objects
        List<SearchResult> results = [];
        for (var item in data) {
          try {
            final lat = double.parse(item['lat']);
            final lon = double.parse(item['lon']);
            final displayName = item['display_name'] ?? '';
            
            if (displayName.isEmpty) continue;

            // Calculate distance if user location is available
            double? distance;
            if (userLocation != null) {
              distance = _calculateDistance(
                userLocation.latitude,
                userLocation.longitude,
                lat,
                lon,
              );
            }

            results.add(SearchResult(
              displayName: displayName,
              coordinates: LatLng(lat, lon),
              distance: distance,
              type: item['type'],
              category: item['category'],
            ));
          } catch (e) {
            print('DEBUG: Error parsing result: $e');
            continue;
          }
        }

        // Sort by distance if user location is available
        if (userLocation != null) {
          results.sort((a, b) {
            if (a.distance != null && b.distance != null) {
              return a.distance!.compareTo(b.distance!);
            }
            return 0;
          });
          
          // Filter results within radius
          results = results.where((r) => r.distance == null || r.distance! <= radiusKm).toList();
        }

        // Save cache
        final normalizedQuery = query.trim().toLowerCase();
        final cacheKey = userLocation != null 
            ? '$normalizedQuery|${userLocation.latitude}|${userLocation.longitude}' 
            : normalizedQuery;
        _cache[cacheKey] = results;

        // Clean cache if too big
        if (_cache.length > 100) {
          _cache.clear();
        }

        // Return display names for backward compatibility
        return results.map((r) => r.displayName).toList();
      }

      return [];
    } catch (e) {
      print('ERROR _performSearch: $e');
      return [];
    }
  }

  /// Calculate distance between two coordinates in km
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Prevent too many requests
  static Future<void> _waitIfNeeded() async {
    final now = DateTime.now();

    if (_lastRequestTime != null) {
      final difference = now.difference(_lastRequestTime!);

      if (difference < _minRequestInterval) {
        final wait = _minRequestInterval - difference;

        print('DEBUG: Waiting ${wait.inMilliseconds}ms');

        await Future.delayed(wait);
      }
    }

    _lastRequestTime = DateTime.now();
  }
}
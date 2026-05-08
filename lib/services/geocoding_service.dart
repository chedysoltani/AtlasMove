import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // Cache
  static final Map<String, List<String>> _cache = {};

  // Rate limit
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 1);

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

  /// Search real address suggestions
  static Future<List<String>> searchAddressSuggestions(
    String query,
  ) async {
    try {
      print('DEBUG: Searching -> "$query"');

      // Prevent useless requests
      if (query.trim().length < 3) {
        return [];
      }

      final normalizedQuery = query.trim().toLowerCase();

      // Cache check
      if (_cache.containsKey(normalizedQuery)) {
        print('DEBUG: Using cache');

        return _cache[normalizedQuery]!;
      }

      // Wait between requests
      await _waitIfNeeded();

      final url =
          '$_baseUrl/search'
          '?format=json'
          '&q=${Uri.encodeComponent(query)}'
          '&limit=5'
          '&addressdetails=1';

      print('DEBUG: URL -> $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AtlasMove/1.0',
          'Accept': 'application/json',
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

        final suggestions =
            data.map<String>((item) {
              return item['display_name'] ?? '';
            }).where((e) => e.isNotEmpty).toList();

        // Save cache
        _cache[normalizedQuery] = suggestions;

        // Clean cache if too big
        if (_cache.length > 50) {
          _cache.clear();
        }

        return suggestions;
      }

      return [];
    } catch (e) {
      print('ERROR searchAddressSuggestions: $e');

      return [];
    }
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
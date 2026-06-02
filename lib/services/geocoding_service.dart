import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SearchResult {
  final String displayName;
  final LatLng coordinates;
  final double? distance;
  final String? type;
  final String? category;
  final String? placeId;

  SearchResult({
    required this.displayName,
    required this.coordinates,
    this.distance,
    this.type,
    this.category,
    this.placeId,
  });
}

class GeocodingService {
  static const String _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode';

  static String get _apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Cache pour les suggestions
  static final Map<String, List<SearchResult>> _cache = {};

  /// Convertir une adresse en coordonnées (Google Geocoding API)
  static Future<LatLng?> getAddressCoordinates(String address) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_geocodeBaseUrl/json'
              '?address=${Uri.encodeComponent(address)}'
              '&key=$_apiKey',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Convertir des coordonnées en adresse (Google Reverse Geocoding API)
  static Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_geocodeBaseUrl/json'
              '?latlng=${coordinates.latitude},${coordinates.longitude}'
              '&key=$_apiKey'
              '&language=fr',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Recherche de suggestions d'adresses (Google Places Autocomplete)
  static Future<List<String>> searchAddressSuggestions(
    String query, {
    LatLng? userLocation,
    double radiusKm = 50,
  }) async {
    try {
      if (query.trim().length < 2) return [];

      final cacheKey = userLocation != null
          ? '${query.trim().toLowerCase()}|${userLocation.latitude}|${userLocation.longitude}'
          : query.trim().toLowerCase();

      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!.map((r) => r.displayName).toList();
      }

      final results = await searchPlaces(query, userLocation: userLocation);

      _cache[cacheKey] = results;
      if (_cache.length > 100) _cache.clear();

      return results.map((r) => r.displayName).toList();
    } catch (e) {
      return [];
    }
  }

  /// Recherche complète retournant des SearchResult avec coordonnées
  static Future<List<SearchResult>> searchPlaces(
    String query, {
    LatLng? userLocation,
  }) async {
    try {
      if (query.trim().length < 2) return [];

      String url = '$_placesBaseUrl/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$_apiKey'
          '&language=fr'
          '&types=geocode|establishment';

      if (userLocation != null) {
        final radiusMeters = 50000;
        url +=
            '&location=${userLocation.latitude},${userLocation.longitude}'
            '&radius=$radiusMeters';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];

      final predictions = data['predictions'] as List;
      final results = <SearchResult>[];

      for (final prediction in predictions.take(8)) {
        final placeId = prediction['place_id'];
        final description = prediction['description'] ?? '';

        if (description.isEmpty) continue;

        // Obtenir les coordonnées via Place Details
        final coords = await _getPlaceCoordinates(placeId);
        if (coords == null) continue;

        results.add(SearchResult(
          displayName: description,
          coordinates: coords,
          placeId: placeId,
        ));
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Obtenir les coordonnées d'un lieu via son place_id
  static Future<LatLng?> _getPlaceCoordinates(String placeId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_placesBaseUrl/details/json'
              '?place_id=$placeId'
              '&fields=geometry'
              '&key=$_apiKey',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtenir les coordonnées d'un lieu depuis son nom affiché
  static Future<LatLng?> getCoordinatesFromDisplayName(
      String displayName) async {
    try {
      // D'abord chercher dans le cache
      for (final results in _cache.values) {
        final match = results.where((r) => r.displayName == displayName);
        if (match.isNotEmpty) return match.first.coordinates;
      }

      // Sinon utiliser le geocoding
      return await getAddressCoordinates(displayName);
    } catch (e) {
      return null;
    }
  }
}

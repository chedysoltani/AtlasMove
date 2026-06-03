import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Headers requis pour les appels REST avec une clé Android restreinte
  static Map<String, String> get _headers => {
        'X-Android-Package': 'com.example.atlasmove',
        'X-Android-Cert': 'FCF536AFE52BF36EFDAE04FCFF1E3B858ED9EB07',
        'Accept': 'application/json',
      };

  // Cache suggestions : displayName → placeId
  static final Map<String, String> _placeIdCache = {};

  // Cache résultats de recherche
  static final Map<String, List<String>> _suggestionsCache = {};

  /// Recherche rapide — retourne juste les noms (pas de coords ici, c'est rapide)
  static Future<List<String>> searchAddressSuggestions(
    String query, {
    LatLng? userLocation,
    double radiusKm = 50,
  }) async {
    try {
      final q = query.trim();
      if (q.length < 2) return [];

      final cacheKey = userLocation != null
          ? '$q|${userLocation.latitude.toStringAsFixed(3)}|${userLocation.longitude.toStringAsFixed(3)}'
          : q;

      if (_suggestionsCache.containsKey(cacheKey)) {
        return _suggestionsCache[cacheKey]!;
      }

      String url = '$_placesBaseUrl/autocomplete/json'
          '?input=${Uri.encodeComponent(q)}'
          '&key=$_apiKey'
          '&language=fr'
          '&types=geocode|establishment';

      if (userLocation != null) {
        url += '&location=${userLocation.latitude},${userLocation.longitude}'
            '&radius=50000';
      }

      debugPrint('GEO: autocomplete → $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      debugPrint('GEO: status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final status = data['status'] as String;
      debugPrint('GEO: Google status = $status');

      if (status == 'ZERO_RESULTS') return [];
      if (status != 'OK') {
        debugPrint('GEO ERROR: ${data['error_message'] ?? status}');
        // Fallback vers Nominatim si Google échoue
        return await _nominatimFallback(q, userLocation);
      }

      final predictions = data['predictions'] as List;
      final names = <String>[];

      for (final p in predictions.take(6)) {
        final desc = (p['description'] ?? '') as String;
        final placeId = (p['place_id'] ?? '') as String;
        if (desc.isEmpty) continue;
        names.add(desc);
        if (placeId.isNotEmpty) _placeIdCache[desc] = placeId;
      }

      _suggestionsCache[cacheKey] = names;
      if (_suggestionsCache.length > 80) _suggestionsCache.clear();

      return names;
    } catch (e) {
      debugPrint('GEO EXCEPTION searchAddressSuggestions: $e');
      return await _nominatimFallback(query.trim(), userLocation);
    }
  }

  /// Convertir un nom de lieu en coordonnées
  /// Utilise le placeId en cache si disponible, sinon Geocoding API, sinon Nominatim
  static Future<LatLng?> getAddressCoordinates(String address) async {
    try {
      // 1. placeId depuis l'autocomplétion (le plus précis)
      final placeId = _placeIdCache[address];
      if (placeId != null) {
        final coords = await _coordsFromPlaceId(placeId);
        if (coords != null) return coords;
      }

      // 2. Google Geocoding API
      final url = '$_geocodeBaseUrl/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_apiKey'
          '&language=fr';

      debugPrint('GEO: geocode → $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      debugPrint('GEO: geocode status=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
        debugPrint('GEO: geocode Google status = ${data['status']}');
      }

      // 3. Fallback Nominatim
      return await _nominatimCoords(address);
    } catch (e) {
      debugPrint('GEO EXCEPTION getAddressCoordinates: $e');
      return await _nominatimCoords(address);
    }
  }

  /// Convertir des coordonnées en adresse lisible
  static Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final url = '$_geocodeBaseUrl/json'
          '?latlng=${coordinates.latitude},${coordinates.longitude}'
          '&key=$_apiKey'
          '&language=fr';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] as String;
        }
      }
      return null;
    } catch (e) {
      debugPrint('GEO EXCEPTION getAddressFromCoordinates: $e');
      return null;
    }
  }

  /// Obtenir les coordonnées depuis un placeId Google
  static Future<LatLng?> _coordsFromPlaceId(String placeId) async {
    try {
      final url = '$_placesBaseUrl/details/json'
          '?place_id=$placeId'
          '&fields=geometry'
          '&key=$_apiKey';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtenir les coordonnées via Nominatim (fallback)
  static Future<LatLng?> _nominatimCoords(String address) async {
    try {
      debugPrint('GEO: Nominatim coords pour "$address"');
      final url = 'https://nominatim.openstreetmap.org/search'
          '?format=json'
          '&q=${Uri.encodeComponent(address)}'
          '&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AtlasMove/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat'] as String),
            double.parse(data[0]['lon'] as String),
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fallback OpenStreetMap Nominatim si Google échoue
  static Future<List<String>> _nominatimFallback(
      String query, LatLng? userLocation) async {
    try {
      debugPrint('GEO: fallback Nominatim pour "$query"');
      String url = 'https://nominatim.openstreetmap.org/search'
          '?format=json'
          '&q=${Uri.encodeComponent(query)}'
          '&limit=6'
          '&addressdetails=1';

      if (userLocation != null) {
        url += '&viewbox=${userLocation.longitude - 0.5},${userLocation.latitude + 0.5}'
            ',${userLocation.longitude + 0.5},${userLocation.latitude - 0.5}'
            '&bounded=0';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AtlasMove/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((item) => (item['display_name'] ?? '') as String)
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Recherche complète avec coordonnées (utilisé si besoin)
  static Future<List<SearchResult>> searchPlaces(
    String query, {
    LatLng? userLocation,
  }) async {
    final names = await searchAddressSuggestions(query, userLocation: userLocation);
    final results = <SearchResult>[];
    for (final name in names) {
      final coords = await getAddressCoordinates(name);
      if (coords != null) {
        results.add(SearchResult(
          displayName: name,
          coordinates: coords,
          placeId: _placeIdCache[name],
        ));
      }
    }
    return results;
  }

  /// Obtenir les coordonnées depuis un nom affiché (cherche dans le cache d'abord)
  static Future<LatLng?> getCoordinatesFromDisplayName(String displayName) async {
    return getAddressCoordinates(displayName);
  }
}

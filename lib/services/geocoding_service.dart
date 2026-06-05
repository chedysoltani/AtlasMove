import 'dart:convert';
import 'dart:math' as math;

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

  static Map<String, String> get _headers => {
        'X-Android-Package': 'com.example.atlasmove',
        'X-Android-Cert': 'FCF536AFE52BF36EFDAE04FCFF1E3B858ED9EB07',
        'Accept': 'application/json',
      };

  // Cache suggestions : displayName → placeId (Google)
  static final Map<String, String> _placeIdCache = {};

  // Cache coordonnées : displayName → LatLng (Photon / Nominatim)
  static final Map<String, LatLng> _coordsCache = {};

  // Cache résultats de recherche
  static final Map<String, List<String>> _suggestionsCache = {};

  /// Recherche rapide — retourne juste les noms affichables
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

      // 1. Google Places Autocomplete
      String url = '$_placesBaseUrl/autocomplete/json'
          '?input=${Uri.encodeComponent(q)}'
          '&key=$_apiKey'
          '&language=fr';

      if (userLocation != null) {
        url += '&location=${userLocation.latitude},${userLocation.longitude}'
            '&radius=50000'
            '&strictbounds=false';
      }

      debugPrint('GEO: autocomplete → $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      debugPrint('GEO: status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String;
        debugPrint('GEO: Google Places status = "$status"');
        if (data['error_message'] != null) {
          debugPrint('GEO: Google error_message = "${data['error_message']}"');
        }

        if (status == 'OK') {
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
        }
        debugPrint('GEO: Google Places échoué ($status) → fallback Photon');
      } else {
        debugPrint('GEO: Google HTTP ${response.statusCode} → fallback Photon');
      }

      // 2. Fallback → Photon (meilleure recherche POI que Nominatim)
      final photonResults = await _photonSearch(q, userLocation);
      if (photonResults.isNotEmpty) {
        _suggestionsCache[cacheKey] = photonResults;
        if (_suggestionsCache.length > 80) _suggestionsCache.clear();
        return photonResults;
      }

      // 3. Fallback final → Nominatim
      return await _nominatimFallback(q, userLocation);
    } catch (e) {
      debugPrint('GEO EXCEPTION searchAddressSuggestions: $e');
      final photonResults = await _photonSearch(query.trim(), userLocation);
      if (photonResults.isNotEmpty) return photonResults;
      return await _nominatimFallback(query.trim(), userLocation);
    }
  }

  /// Supprime les mots de catégorie de la requête pour la recherche par nom pur
  /// Ex: "ace london café" → "ace london", "restaurant chez pierre" → "chez pierre"
  static String _stripTypeWords(String query) {
    const typeWords = [
      'café', 'cafe', 'coffee', 'restaurant', 'resto', 'restau',
      'hôtel', 'hotel', 'pharmacie', 'pharmacy', 'supermarché',
      'supermarket', 'boulangerie', 'pâtisserie', 'patisserie',
      'pizzeria', 'snack', 'fast food', 'fastfood', 'épicerie',
      'banque', 'bank', 'clinique', 'clinic', 'hôpital', 'hospital',
      'école', 'ecole', 'école', 'université', 'universite',
      'parc', 'park', 'jardin', 'plage', 'beach', 'stade', 'stadium',
      'mosquée', 'mosquee', 'église', 'eglise', 'marché', 'marche',
    ];
    var cleaned = query.trim();
    for (final word in typeWords) {
      cleaned = cleaned.replaceAll(
          RegExp(r'\b' + word + r'\b', caseSensitive: false), '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? query : cleaned;
  }

  /// Convertir un nom de lieu en coordonnées
  static Future<LatLng?> getAddressCoordinates(String address) async {
    try {
      // 1. Coordonnées en cache (depuis Photon ou sélection précédente)
      final cached = _coordsCache[address];
      if (cached != null) return cached;

      // 2. placeId depuis l'autocomplétion Google
      final placeId = _placeIdCache[address];
      if (placeId != null) {
        final coords = await _coordsFromPlaceId(placeId);
        if (coords != null) return coords;
      }

      // 3. Google Geocoding API
      final url = '$_geocodeBaseUrl/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_apiKey'
          '&language=fr';

      debugPrint('GEO: geocode → $url');
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
        debugPrint('GEO: geocode Google status = ${data['status']}');
      }

      // 4. Photon reverse lookup
      final photonCoords = await _photonCoords(address);
      if (photonCoords != null) return photonCoords;

      // 5. Nominatim coords
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

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final h = sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinDLon *
            sinDLon;
    return 2 * r * math.asin(math.sqrt(h));
  }

  // ─── Photon (komoot) ────────────────────────────────────────────────────────

  /// Recherche POI via Photon — biais de localisation natif, bien meilleur que Nominatim pour les POIs
  static Future<List<String>> _photonSearch(
      String query, LatLng? userLocation) async {
    try {
      debugPrint('GEO: Photon search pour "$query"');
      final cleanedQuery = _stripTypeWords(query);
      final double? bbox = userLocation != null ? 1.5 : null;

      final osmTag = _detectOsmTag(query);

      // Recherches parallèles : requête originale + requête nettoyée (sans mots de type)
      // Si type détecté (ex: "café"), chercher aussi par nom pur avec filtre osm_tag
      final futures = [
        _photonRequest(query, userLocation, bboxDegrees: bbox),
        if (cleanedQuery != query)
          _photonRequest(cleanedQuery, userLocation,
              bboxDegrees: bbox, osmTag: osmTag),
      ];
      final allResults = await Future.wait(futures);

      // Fusionner et dédupliquer par nom (priorité à la requête originale)
      final seen = <String>{};
      final merged = <String>[];
      for (final list in allResults) {
        for (final name in list) {
          final key = name.toLowerCase();
          if (seen.add(key)) merged.add(name);
        }
      }

      // Si bbox vide → réessayer avec bbox élargi (±3°, ~330km, couvre tout le pays)
      // puis filtrer par distance pour ne jamais afficher des résultats d'autres continents
      if (merged.isEmpty && userLocation != null) {
        debugPrint('GEO: Photon bbox vide, retry bbox élargi ±3°');
        final r1 = await _photonRequest(query, userLocation, bboxDegrees: 3.0);
        final r2 = cleanedQuery != query
            ? await _photonRequest(cleanedQuery, userLocation,
                bboxDegrees: 3.0, osmTag: osmTag)
            : <String>[];
        final seen2 = <String>{};
        for (final name in [...r1, ...r2]) {
          if (seen2.add(name.toLowerCase())) merged.add(name);
        }
      }

      // Filtre final : exclure résultats à plus de 400km (évite UK/Chine quand bbox échoue)
      if (userLocation != null) {
        merged.retainWhere((name) {
          final coords = _coordsCache[name];
          if (coords == null) return true;
          return _distanceKm(userLocation, coords) <= 400;
        });
      }

      debugPrint('GEO: Photon → ${merged.length} résultats');
      return merged;
    } catch (e) {
      debugPrint('GEO EXCEPTION _photonSearch: $e');
      return [];
    }
  }

  /// Détecte un tag OSM depuis la requête pour filtrer par type de POI
  static String? _detectOsmTag(String query) {
    final q = query.toLowerCase();
    if (q.contains('café') || q.contains('cafe') || q.contains('coffee')) return 'amenity:cafe';
    if (q.contains('restaurant') || q.contains('resto') || q.contains('restau')) return 'amenity:restaurant';
    if (q.contains('pizzeria')) return 'amenity:restaurant';
    if (q.contains('hôtel') || q.contains('hotel')) return 'tourism:hotel';
    if (q.contains('pharmacie') || q.contains('pharmacy')) return 'amenity:pharmacy';
    if (q.contains('hôpital') || q.contains('hospital') || q.contains('clinique')) return 'amenity:hospital';
    if (q.contains('supermarché') || q.contains('supermarket') || q.contains('épicerie')) return 'shop:supermarket';
    if (q.contains('boulangerie') || q.contains('pâtisserie') || q.contains('patisserie')) return 'shop:bakery';
    if (q.contains('banque') || q.contains('bank')) return 'amenity:bank';
    if (q.contains('parc') || q.contains('park') || q.contains('jardin')) return 'leisure:park';
    if (q.contains('mosquée') || q.contains('mosquee')) return 'amenity:place_of_worship';
    if (q.contains('stade') || q.contains('stadium')) return 'leisure:stadium';
    if (q.contains('marché') || q.contains('marche')) return 'amenity:marketplace';
    return null;
  }

  static Future<List<String>> _photonRequest(
      String query, LatLng? userLocation,
      {double? bboxDegrees, String? osmTag}) async {
    String url = 'https://photon.komoot.io/api/'
        '?q=${Uri.encodeComponent(query)}'
        '&limit=10'
        '&lang=fr';

    if (userLocation != null) {
      url += '&lat=${userLocation.latitude}&lon=${userLocation.longitude}';
      if (bboxDegrees != null) {
        final d = bboxDegrees;
        final minLon = userLocation.longitude - d;
        final minLat = userLocation.latitude - d;
        final maxLon = userLocation.longitude + d;
        final maxLat = userLocation.latitude + d;
        url += '&bbox=$minLon,$minLat,$maxLon,$maxLat';
      }
    }

    if (osmTag != null) {
      url += '&osm_tag=${Uri.encodeComponent(osmTag)}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'AtlasMove/1.0'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map;
    final features = (data['features'] as List?) ?? [];
    final results = <String>[];

    for (final feature in features) {
      final props = (feature['properties'] as Map?) ?? {};
      final name = (props['name'] as String?) ?? '';
      if (name.isEmpty) continue;

      final street = (props['street'] as String?) ?? '';
      final housenumber = (props['housenumber'] as String?) ?? '';
      final city = (props['city'] as String?) ??
          (props['town'] as String?) ??
          (props['village'] as String?) ??
          '';
      final country = (props['country'] as String?) ?? '';

      final parts = <String>[name];
      if (housenumber.isNotEmpty && street.isNotEmpty) {
        parts.add('$housenumber $street');
      } else if (street.isNotEmpty && street != name) {
        parts.add(street);
      }
      if (city.isNotEmpty && city != name) parts.add(city);
      if (country.isNotEmpty) parts.add(country);

      final displayName = parts.join(', ');
      results.add(displayName);

      // Stocker les coordonnées pour usage immédiat sans appel supplémentaire
      final geometry = feature['geometry'] as Map?;
      final coords = geometry?['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        final lat = (coords[1] as num).toDouble();
        final lon = (coords[0] as num).toDouble();
        _coordsCache[displayName] = LatLng(lat, lon);
      }
    }

    return results;
  }

  /// Obtenir les coordonnées via Photon pour une adresse texte
  static Future<LatLng?> _photonCoords(String address) async {
    try {
      final url = 'https://photon.komoot.io/api/'
          '?q=${Uri.encodeComponent(address)}'
          '&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AtlasMove/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map;
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final coords = features[0]['geometry']['coordinates'] as List;
          return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Google Places Details ──────────────────────────────────────────────────

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

  // ─── Nominatim (dernier recours) ────────────────────────────────────────────

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

  static Future<List<String>> _nominatimFallback(
      String query, LatLng? userLocation) async {
    try {
      debugPrint('GEO: fallback Nominatim pour "$query"');
      String url = 'https://nominatim.openstreetmap.org/search'
          '?format=json'
          '&q=${Uri.encodeComponent(query)}'
          '&limit=8'
          '&addressdetails=1'
          '&namedetails=1';

      if (userLocation != null) {
        // viewbox ±0.25° (~27km) pour rester dans la zone locale
        final double d = 0.25;
        url += '&viewbox=${userLocation.longitude - d},${userLocation.latitude + d}'
            ',${userLocation.longitude + d},${userLocation.latitude - d}'
            '&bounded=1';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AtlasMove/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        List<String> results = data
            .map((item) => (item['display_name'] ?? '') as String)
            .where((s) => s.isNotEmpty)
            .toList();

        // Si zone locale vide, réessayer sans restriction géographique
        if (results.isEmpty && userLocation != null) {
          final fallbackUrl = 'https://nominatim.openstreetmap.org/search'
              '?format=json'
              '&q=${Uri.encodeComponent(query)}'
              '&limit=8'
              '&addressdetails=1';
          final r2 = await http.get(
            Uri.parse(fallbackUrl),
            headers: {'User-Agent': 'AtlasMove/1.0'},
          ).timeout(const Duration(seconds: 8));
          if (r2.statusCode == 200) {
            final List d2 = json.decode(r2.body);
            results = d2
                .map((item) => (item['display_name'] ?? '') as String)
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }

        return results;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── Public helpers ─────────────────────────────────────────────────────────

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

  static Future<LatLng?> getCoordinatesFromDisplayName(String displayName) async {
    return getAddressCoordinates(displayName);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });
}

class RouteService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Fetches a driving route between two points using the public OSRM API.
  static Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = '$_baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline&overview=full';
      debugPrint('🌐 Fetching Route: $url');
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String;
          final distance = (route['distance'] as num).toDouble() / 1000; // Convert to km
          final duration = (route['duration'] as num).toInt(); // in seconds
          
          final points = _decodePolyline(geometry);
          
          return RouteResult(
            points: points,
            distanceKm: distance,
            durationSeconds: duration,
          );
        }
      } else {
        debugPrint('❌ Failed to fetch route. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching route: $e');
    }
    return null;
  }

  /// Decodes an encoded polyline string into a list of LatLng points.
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }

    return poly;
  }
}

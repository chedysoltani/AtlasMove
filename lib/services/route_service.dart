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

class RouteLeg {
  final double distanceKm;
  final int durationSeconds;

  RouteLeg({required this.distanceKm, required this.durationSeconds});
}

class MultiRouteResult {
  final List<LatLng> points;
  final List<RouteLeg> legs;

  MultiRouteResult({required this.points, required this.legs});

  double get totalDistanceKm =>
      legs.fold(0.0, (sum, leg) => sum + leg.distanceKm);

  int get totalDurationSeconds =>
      legs.fold(0, (sum, leg) => sum + leg.durationSeconds);
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

  /// Fetches a driving route through an ordered list of waypoints
  /// (pickup, followed by each destination in visiting order) using OSRM.
  /// Returns one leg per consecutive pair of waypoints, plus the combined
  /// route geometry. Returns null on any failure — callers must not
  /// substitute a straight-line fallback for multi-stop legs.
  static Future<MultiRouteResult?> getMultiWaypointRoute(
      List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = '$_baseUrl/$coords?geometries=polyline&overview=full';
      debugPrint('🌐 Fetching Multi-Waypoint Route: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String;
          final legsJson = route['legs'] as List;

          final legs = legsJson.map((legJson) {
            final distance = (legJson['distance'] as num).toDouble() / 1000;
            final duration = (legJson['duration'] as num).toInt();
            return RouteLeg(distanceKm: distance, durationSeconds: duration);
          }).toList();

          if (legs.length != waypoints.length - 1) return null;

          return MultiRouteResult(
            points: _decodePolyline(geometry),
            legs: legs,
          );
        }
      } else {
        debugPrint('❌ Failed to fetch multi-waypoint route. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching multi-waypoint route: $e');
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

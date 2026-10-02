import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Petites fonctions géodésiques partagées (distance, cap, angles).
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusM = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Distance haversine en mètres.
  static double distanceM(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final s1 = math.sin(dLat / 2), s2 = math.sin(dLng / 2);
    final h = s1 * s1 +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * s2 * s2;
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Cap initial (0–360°, 0 = nord) de [from] vers [to].
  static double bearing(LatLng from, LatLng to) {
    final lat1 = _rad(from.latitude), lat2 = _rad(to.latitude);
    final dLng = _rad(to.longitude - from.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return normalizeAngle(math.atan2(y, x) * 180.0 / math.pi);
  }

  static double normalizeAngle(double deg) => ((deg % 360) + 360) % 360;

  /// Interpolation d'angle par le plus court chemin (évite le tour complet 350°→10°).
  static double lerpAngle(double from, double to, double t) {
    var diff = normalizeAngle(to) - normalizeAngle(from);
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return normalizeAngle(from + diff * t);
  }

  static LatLng lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  /// Longueur cumulée d'une polyligne en mètres.
  static double pathLengthM(List<LatLng> pts, [int from = 0]) {
    var total = 0.0;
    for (var i = from; i < pts.length - 1; i++) {
      total += distanceM(pts[i], pts[i + 1]);
    }
    return total;
  }
}

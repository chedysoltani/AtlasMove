import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cadrage automatique robuste (fitBounds).
class MapCamera {
  MapCamera._();

  /// Cadre tous les [points] avec [padding] (px). Tolère : un seul point,
  /// bornes quasi nulles (on impose une étendue minimale ≈ 300 m pour ne pas
  /// zoomer à l'extrême) et carte pas encore mesurée (une nouvelle tentative).
  static Future<void> fitBounds(
    GoogleMapController? controller,
    Iterable<LatLng> points, {
    double padding = 80,
  }) async {
    if (controller == null) return;
    final pts = points.toList();
    if (pts.isEmpty) return;

    var minLat = pts.first.latitude, maxLat = minLat;
    var minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    const minSpan = 0.003;
    if (maxLat - minLat < minSpan) {
      final c = (maxLat + minLat) / 2;
      minLat = c - minSpan / 2;
      maxLat = c + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final c = (maxLng + minLng) / 2;
      minLng = c - minSpan / 2;
      maxLng = c + minSpan / 2;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    Future<void> attempt() =>
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));

    try {
      await attempt();
    } catch (_) {
      // Carte pas encore dimensionnée : on retente une fois puis on se replie.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      try {
        await attempt();
      } catch (e) {
        debugPrint('MapCamera.fitBounds fallback: $e');
        try {
          await controller.animateCamera(CameraUpdate.newLatLngZoom(
              LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 14));
        } catch (_) {}
      }
    }
  }
}

/// Gère « la caméra suit le chauffeur » avec reprise en main manuelle.
///
/// Dès que l'utilisateur touche la carte, le suivi est suspendu ([isFollowing]
/// passe à false) ; [recenter] le réactive (bouton de recentrage).
class FollowCamera {
  final ValueNotifier<bool> isFollowing = ValueNotifier<bool>(true);
  GoogleMapController? _controller;

  GoogleMapController? get controller => _controller;

  void attach(GoogleMapController controller) => _controller = controller;

  /// Le doigt a touché la carte : l'utilisateur reprend le contrôle.
  void onUserGesture() {
    if (isFollowing.value) isFollowing.value = false;
  }

  /// Déplace la caméra uniquement si le suivi est actif.
  Future<void> follow(CameraUpdate update) async {
    if (!isFollowing.value) return;
    await _animate(update);
  }

  /// Réactive le suivi et déplace la caméra.
  Future<void> recenter(CameraUpdate update) async {
    isFollowing.value = true;
    await _animate(update);
  }

  Future<void> _animate(CameraUpdate update) async {
    try {
      await _controller?.animateCamera(update);
    } catch (e) {
      debugPrint('FollowCamera: $e');
    }
  }

  void dispose() {
    _controller = null;
    isFollowing.dispose();
  }
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_utils.dart';
import 'map_styles.dart';

/// Tracé d'itinéraire « propre » : bordure sombre + trait orange arrondi, avec
/// animation de révélation à l'arrivée d'un nouvel itinéraire, et mise à jour
/// dynamique quand le chauffeur avance (la partie parcourue passe en gris).
///
/// Émet le `Set<Polyline>` via [polylines] ; l'appelant l'affiche avec un
/// `ValueListenableBuilder` pour ne reconstruire que la carte.
class RouteOverlay {
  RouteOverlay({
    required TickerProvider vsync,
    this.color = MapStyles.brandOrange,
    this.revealDuration = const Duration(milliseconds: 800),
  }) {
    _reveal = AnimationController(vsync: vsync, duration: revealDuration)
      ..addListener(_onRevealTick);
  }

  final Color color;
  final Duration revealDuration;
  late final AnimationController _reveal;

  static const PolylineId _outlineId = PolylineId('route_outline');
  static const PolylineId _mainId = PolylineId('route_main');
  static const PolylineId _doneId = PolylineId('route_done');

  /// En dessous de cette distance la position est considérée « sur » l'itinéraire.
  static const double offRouteThresholdM = 80;

  /// Fenêtre de recherche (en segments) devant le dernier point franchi : le
  /// tracé ne peut pas « reculer » et la recherche reste O(1).
  static const int _searchWindow = 60;

  final ValueNotifier<Set<Polyline>> polylines =
      ValueNotifier<Set<Polyline>>(const <Polyline>{});

  List<LatLng> _points = const [];
  int _doneIdx = 0;
  LatLng? _head;
  LatLng? _lastEmittedHead;
  int _lastEmittedIdx = -1;
  double _totalM = 0;
  double? _durationS;
  bool _offRoute = false;
  Duration _lastRevealEmit = Duration.zero;
  bool _disposed = false;

  bool get hasRoute => _points.length >= 2;

  /// La dernière position transmise à [updateProgress] est loin du tracé.
  bool get isOffRoute => _offRoute;

  double get totalMeters => _totalM;

  double get remainingMeters {
    if (!hasRoute) return 0;
    final head = _head;
    final rest = GeoUtils.pathLengthM(_points, math.min(_doneIdx + 1, _points.length - 1));
    if (head == null || _doneIdx + 1 >= _points.length) return rest;
    return rest + GeoUtils.distanceM(head, _points[_doneIdx + 1]);
  }

  /// Durée restante estimée (durée OSRM proportionnelle à la distance restante).
  double? get remainingSeconds {
    final d = _durationS;
    if (d == null || _totalM <= 0) return null;
    return d * (remainingMeters / _totalM).clamp(0.0, 1.0);
  }

  void setRoute(
    List<LatLng> points, {
    double? durationSeconds,
    LatLng? head,
    bool animate = true,
  }) {
    if (points.length < 2) {
      clear();
      return;
    }
    final first = _points.isEmpty;
    _points = points;
    _doneIdx = 0;
    _totalM = GeoUtils.pathLengthM(points);
    _durationS = durationSeconds;
    _head = head ?? points.first;
    _lastEmittedHead = null;
    _lastEmittedIdx = -1;
    _offRoute = false;
    if (head != null) _advance(head);
    if (animate && first) {
      _lastRevealEmit = Duration.zero;
      _reveal.forward(from: 0);
    } else {
      _reveal.stop();
      _emit(force: true, revealT: 1);
    }
  }

  void clear() {
    _reveal.stop();
    _points = const [];
    _doneIdx = 0;
    _head = null;
    _totalM = 0;
    _durationS = null;
    _offRoute = false;
    if (!_disposed) polylines.value = const <Polyline>{};
  }

  /// À appeler avec la position affichée du chauffeur.
  void updateProgress(LatLng driver) {
    if (!hasRoute || _disposed) return;
    _head = driver;
    _advance(driver);
    if (_reveal.isAnimating) return; // le tick d'animation émettra
    _emit(revealT: 1);
  }

  void _advance(LatLng p) {
    final last = _points.length - 2;
    if (last < 0) return;
    var bestI = _doneIdx.clamp(0, last);
    var bestD = double.infinity;
    final end = math.min(last, bestI + _searchWindow);
    for (var i = bestI; i <= end; i++) {
      final d = _distanceToSegmentM(p, _points[i], _points[i + 1]);
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    _offRoute = bestD > offRouteThresholdM;
    if (!_offRoute) _doneIdx = bestI;
  }

  void _onRevealTick() {
    final done = _reveal.value >= 1;
    final elapsed = _reveal.lastElapsedDuration ?? Duration.zero;
    if (!done && elapsed >= _lastRevealEmit &&
        elapsed - _lastRevealEmit < const Duration(milliseconds: 50)) {
      return;
    }
    _lastRevealEmit = elapsed;
    _emit(force: true, revealT: Curves.easeOut.transform(_reveal.value));
  }

  void _emit({bool force = false, required double revealT}) {
    if (_disposed || !hasRoute) return;
    final head = _head ?? _points.first;

    if (!force) {
      // Évite de ré-encoder une longue polyligne vers la plateforme à chaque
      // frame : on n'émet que si un sommet est franchi ou après ~10 m.
      final movedEnough = _lastEmittedHead == null ||
          GeoUtils.distanceM(_lastEmittedHead!, head) >= 10;
      if (_doneIdx == _lastEmittedIdx && !movedEnough) return;
    }
    _lastEmittedIdx = _doneIdx;
    _lastEmittedHead = head;

    final startIdx = math.min(_doneIdx + 1, _points.length - 1);
    var remaining = <LatLng>[head, ..._points.sublist(startIdx)];
    if (revealT < 1) {
      final n = math.max(2, (remaining.length * revealT).ceil());
      remaining = remaining.sublist(0, math.min(n, remaining.length));
    }

    final set = <Polyline>{};
    if (_doneIdx > 0) {
      set.add(Polyline(
        polylineId: _doneId,
        points: [..._points.sublist(0, _doneIdx + 1), head],
        color: const Color(0xFF9E9E9E).withOpacity(0.55),
        width: 7,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 0,
      ));
    }
    set.add(Polyline(
      polylineId: _outlineId,
      points: remaining,
      color: const Color(0xFF000000).withOpacity(0.30),
      width: 12,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      zIndex: 1,
    ));
    set.add(Polyline(
      polylineId: _mainId,
      points: remaining,
      color: color,
      width: 8,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      zIndex: 2,
    ));
    polylines.value = set;
  }

  /// Distance (m) d'un point au segment [a,b], approximation plane locale.
  static double _distanceToSegmentM(LatLng p, LatLng a, LatLng b) {
    const r = 6371000.0;
    final cosLat = math.cos(a.latitude * math.pi / 180.0);
    double x(LatLng q) => (q.longitude - a.longitude) * math.pi / 180.0 * cosLat * r;
    double y(LatLng q) => (q.latitude - a.latitude) * math.pi / 180.0 * r;
    final px = x(p), py = y(p), bx = x(b), by = y(b);
    final len2 = bx * bx + by * by;
    final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    final dx = px - bx * t, dy = py - by * t;
    return math.sqrt(dx * dx + dy * dy);
  }

  void dispose() {
    _disposed = true;
    _reveal.dispose();
    polylines.dispose();
  }
}

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_utils.dart';
import 'map_styles.dart';

/// Une position GPS (locale ou reçue du backend) avant filtrage.
class DriverFix {
  final LatLng position;

  /// Cap en degrés. `null` ou négatif = inconnu.
  final double? heading;
  final double? speedMps;
  final double? accuracyM;
  final DateTime timestamp;

  const DriverFix({
    required this.position,
    this.heading,
    this.speedMps,
    this.accuracyM,
    required this.timestamp,
  });
}

/// Filtre les positions aberrantes : précision GPS faible, sauts irréalistes,
/// positions hors-ordre, micro-jitter à l'arrêt.
class DriverFixFilter {
  DriverFixFilter({
    this.maxAccuracyM = 50,
    this.maxSpeedMps = 70, // ≈ 250 km/h
    this.minMoveM = 2,
    this.resyncAfterJumps = 3,
    this.relaxAfterLowAccuracy = 5,
  });

  final double maxAccuracyM;
  final double maxSpeedMps;
  final double minMoveM;

  /// Après N sauts consécutifs rejetés on considère que le chauffeur a
  /// réellement changé de zone (tunnel, reconnexion) et on ré-ancre.
  final int resyncAfterJumps;

  /// Après N fixes consécutifs trop imprécis on accepte une précision dégradée
  /// (≤ 3× le seuil) plutôt que de figer le marqueur en zone couverte.
  final int relaxAfterLowAccuracy;

  DriverFix? _last;
  int _jumpStreak = 0;
  int _lowAccuracyStreak = 0;

  DriverFix? get last => _last;

  void reset() {
    _last = null;
    _jumpStreak = 0;
    _lowAccuracyStreak = 0;
  }

  /// Retourne le fix à utiliser, ou `null` s'il est rejeté / sans effet visible.
  DriverFix? accept(DriverFix fix) {
    final p = fix.position;
    if (p.latitude.isNaN ||
        p.longitude.isNaN ||
        (p.latitude == 0 && p.longitude == 0) ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180) {
      return null;
    }

    final acc = fix.accuracyM;
    if (acc != null && acc > maxAccuracyM) {
      _lowAccuracyStreak++;
      // Une position grossière vaut mieux que pas de marqueur du tout : on
      // l'accepte pour le tout premier fix, ou après une série de fixes imprécis.
      final tolerated = acc <= maxAccuracyM * 3 &&
          (_last == null || _lowAccuracyStreak >= relaxAfterLowAccuracy);
      if (!tolerated) return null;
    } else {
      _lowAccuracyStreak = 0;
    }

    final last = _last;
    if (last == null) {
      _last = fix;
      return fix;
    }

    final dtSec =
        fix.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
    if (dtSec < 0) return null; // hors-ordre

    final dist = GeoUtils.distanceM(last.position, p);
    if (dist > 30) {
      final impliedSpeed = dtSec > 0.05 ? dist / dtSec : double.infinity;
      if (impliedSpeed > maxSpeedMps) {
        _jumpStreak++;
        if (_jumpStreak < resyncAfterJumps) return null;
      }
    }
    _jumpStreak = 0;

    if (dist < minMoveM) return null;

    _last = fix;
    return fix;
  }
}

/// Possède UN SEUL marqueur chauffeur (`driver_marker`) et le fait glisser
/// d'une position à la suivante.
///
/// - id constant : une mise à jour remplace toujours le même marqueur.
/// - interpolation lat/lng linéaire, durée ≥ 1 s (adaptée à l'intervalle réel
///   entre deux positions, plafonnée) → pas de téléportation.
/// - rotation lissée par le plus court chemin ; le cap est ignoré quand la
///   vitesse est quasi nulle.
/// - n'émet un nouveau [Marker] que toutes les [emitInterval] (≈ 25 fps) pour
///   ne pas saturer le canal plateforme de la carte.
class DriverMarkerController {
  static const MarkerId markerId = MarkerId('driver_marker');

  /// Sous ce seuil (m/s ≈ 3,6 km/h) on considère le véhicule à l'arrêt.
  static const double minSpeedForBearing = 1.0;

  /// Au-delà de cette distance le marqueur est repositionné sans animation.
  static const double snapDistanceM = 1500;

  DriverMarkerController({
    required TickerProvider vsync,
    this.minDuration = const Duration(milliseconds: 1000),
    this.maxDuration = const Duration(milliseconds: 2500),
    this.emitInterval = const Duration(milliseconds: 40),
    DriverFixFilter? filter,
  }) : _filter = filter ?? DriverFixFilter() {
    _anim = AnimationController(vsync: vsync)..addListener(_onTick);
  }

  final Duration minDuration;
  final Duration maxDuration;
  final Duration emitInterval;
  final DriverFixFilter _filter;
  late final AnimationController _anim;

  /// Le marqueur à afficher (null tant qu'aucune position / aucune icône).
  final ValueNotifier<Marker?> marker = ValueNotifier<Marker?>(null);

  BitmapDescriptor? _icon;
  double _alpha = 1.0;
  LatLng? _current, _from, _to;
  double _bearing = 0, _bearingFrom = 0, _bearingTo = 0;
  DateTime? _lastArrival;
  DateTime? _lastFixTs;
  Duration _lastEmitAt = Duration.zero; // temps d'animation du dernier envoi
  bool _disposed = false;

  /// Position interpolée actuellement affichée.
  LatLng? get position => _current;

  /// Dernière position cible reçue (où le marqueur est en train d'aller).
  LatLng? get target => _to;

  double get bearing => _bearing;
  bool get hasPosition => _current != null;

  void setIcon(BitmapDescriptor icon) {
    _icon = icon;
    _emit();
  }

  /// Opacité du marqueur (ex. atténué quand le chauffeur est hors ligne).
  set alpha(double value) {
    _alpha = value;
    _emit();
  }

  /// Oublie tout (ex. fin de course) et retire le marqueur.
  void reset() {
    _anim.stop();
    _filter.reset();
    _current = _from = _to = null;
    _lastArrival = _lastFixTs = null;
    _bearing = _bearingFrom = _bearingTo = 0;
    if (!_disposed) marker.value = null;
  }

  /// Soumet une position. Retourne `true` si elle a été acceptée.
  bool update(DriverFix fix) {
    if (_disposed) return false;
    final accepted = _filter.accept(fix);
    if (accepted == null) return false;

    final now = DateTime.now();
    final target = accepted.position;
    final current = _current;

    if (current == null) {
      _current = _from = _to = target;
      final h = accepted.heading;
      if (h != null && h >= 0 && (accepted.speedMps ?? 0) >= minSpeedForBearing) {
        _bearing = _bearingFrom = _bearingTo = GeoUtils.normalizeAngle(h);
      }
      _lastArrival = now;
      _lastFixTs = accepted.timestamp;
      _emit();
      return true;
    }

    final dist = GeoUtils.distanceM(current, target);
    final newBearing = _resolveBearing(accepted, current, dist);

    // Durée d'animation : intervalle réel entre les deux dernières positions
    // (le marqueur arrive quand la suivante est attendue), borné [min, max].
    var duration = minDuration;
    if (_lastArrival != null) {
      final gap = now.difference(_lastArrival!);
      if (gap > duration) duration = gap > maxDuration ? maxDuration : gap;
    }
    _lastArrival = now;
    _lastFixTs = accepted.timestamp;

    if (dist > snapDistanceM) {
      _anim.stop();
      _current = _from = _to = target;
      _bearing = _bearingFrom = _bearingTo = newBearing;
      _emit();
      return true;
    }

    _from = current;
    _to = target;
    _bearingFrom = _bearing;
    _bearingTo = newBearing;
    _anim.duration = duration;
    _lastEmitAt = Duration.zero;
    _anim.forward(from: 0);
    return true;
  }

  double _resolveBearing(DriverFix fix, LatLng current, double distFromCurrent) {
    // Vitesse : celle du capteur, sinon déduite du déplacement.
    var speed = fix.speedMps;
    if (speed == null) {
      final dt = _lastFixTs == null
          ? 0.0
          : fix.timestamp.difference(_lastFixTs!).inMilliseconds / 1000.0;
      speed = dt > 0.3 ? distFromCurrent / dt : distFromCurrent;
    }
    if (speed < minSpeedForBearing) return _bearingTo; // à l'arrêt : on garde le cap

    final h = fix.heading;
    final headingKnown = h != null && !h.isNaN && h >= 0 && h <= 360;
    final moved = distFromCurrent >= 6;
    double? movement;
    if (moved) movement = GeoUtils.bearing(current, fix.position);

    double resolved;
    if (headingKnown && !(h == 0 && movement != null)) {
      // heading == 0 exact est très souvent « inconnu » côté capteur/backend
      resolved = GeoUtils.normalizeAngle(h);
    } else if (movement != null) {
      resolved = movement;
    } else {
      return _bearingTo;
    }
    // Filtre passe-bas : pas de saut brusque sur un cap bruité.
    return GeoUtils.lerpAngle(_bearingTo, resolved, 0.6);
  }

  void _onTick() {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final t = _anim.value;
    _current = GeoUtils.lerpLatLng(from, to, t);
    _bearing = GeoUtils.lerpAngle(_bearingFrom, _bearingTo, Curves.easeOut.transform(t));
    // Limite le débit vers la plateforme (≈ 25 fps) ; la dernière image est toujours envoyée.
    final elapsed = _anim.lastElapsedDuration ?? Duration.zero;
    if (t < 1 && elapsed >= _lastEmitAt && elapsed - _lastEmitAt < emitInterval) return;
    _lastEmitAt = elapsed;
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    final pos = _current, icon = _icon;
    if (pos == null || icon == null) return;
    marker.value = Marker(
      markerId: markerId,
      position: pos,
      rotation: _bearing,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      icon: icon,
      alpha: _alpha,
      zIndexInt: 10,
    );
  }

  void dispose() {
    _disposed = true;
    _anim.dispose();
    marker.dispose();
  }
}

/// Icône de repli si le rendu des bitmaps échoue.
BitmapDescriptor fallbackDriverIcon() =>
    BitmapDescriptor.defaultMarkerWithHue(
        HSVColor.fromColor(MapStyles.brandOrange).hue);

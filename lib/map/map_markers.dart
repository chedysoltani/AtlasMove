import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_styles.dart';

/// Catégorie de véhicule affichée sur la carte.
enum VehicleCategory {
  car,
  moto,
  truck;

  /// Déduit la catégorie d'un libellé libre (« Moto standard », « camion », slug transport…).
  /// Toute valeur inconnue retombe sur la voiture.
  static VehicleCategory fromLabel(String? label) {
    final v = (label ?? '').toLowerCase();
    const motoKeys = ['moto', 'scooter', 'bike', 'velo', 'vélo', 'tricycle', 'tuk'];
    const truckKeys = [
      'camion', 'truck', 'utilitaire', 'fourgon', 'van', 'remorque', 'semi',
      'tracteur', 'engins', 'chariot',
    ];
    if (motoKeys.any(v.contains)) return VehicleCategory.moto;
    if (truckKeys.any(v.contains)) return VehicleCategory.truck;
    return VehicleCategory.car;
  }
}

/// Fabrique de [BitmapDescriptor] haute résolution, mis en cache.
///
/// Chaque icône est dessinée une seule fois par (type, densité d'écran) puis
/// réutilisée : aucun re-rendu à chaque frame ni à chaque rebuild d'écran.
/// Les icônes véhicule sont dessinées vues du dessus, avant vers le HAUT, pour
/// que `Marker.rotation = bearing` avec `flat: true` fonctionne directement.
class MapMarkerFactory {
  MapMarkerFactory._();
  static final MapMarkerFactory instance = MapMarkerFactory._();

  static const Color _orange = MapStyles.brandOrange;
  static const Color _orangeDark = Color(0xFFD95500);
  static const Color _ink = Color(0xFF1E1E1E);

  static const double _vehicleSize = 56;
  static const double _pinW = 40, _pinH = 52;

  final Map<String, Future<BitmapDescriptor>> _cache = {};

  /// Densité normalisée (pas de 0.5, bornée) pour garder un cache stable.
  static double normalizeDpr(double dpr) =>
      ((dpr.clamp(1.0, 4.0) * 2).round() / 2).toDouble();

  Future<BitmapDescriptor> vehicle(VehicleCategory category, double dpr) {
    final d = normalizeDpr(dpr);
    return _cache.putIfAbsent('veh_${category.name}_$d', () {
      switch (category) {
        case VehicleCategory.car:
          return _render(_vehicleSize, _vehicleSize, d, _paintCar);
        case VehicleCategory.moto:
          return _render(_vehicleSize, _vehicleSize, d, _paintMoto);
        case VehicleCategory.truck:
          return _render(_vehicleSize, _vehicleSize, d, _paintTruck);
      }
    });
  }

  /// Pin de départ : goutte orange, point blanc. Ancrage conseillé : (0.5, 1.0).
  Future<BitmapDescriptor> pickupPin(double dpr) {
    final d = normalizeDpr(dpr);
    return _cache.putIfAbsent(
        'pin_start_$d', () => _render(_pinW, _pinH, d, (c) => _paintPin(c, false)));
  }

  /// Pin de destination : goutte orange, carré blanc. Ancrage conseillé : (0.5, 1.0).
  Future<BitmapDescriptor> destinationPin(double dpr) {
    final d = normalizeDpr(dpr);
    return _cache.putIfAbsent(
        'pin_end_$d', () => _render(_pinW, _pinH, d, (c) => _paintPin(c, true)));
  }

  /// Point « vous êtes ici » (bleu, anneau blanc). Ancrage : (0.5, 0.5).
  Future<BitmapDescriptor> userLocationDot(double dpr) {
    final d = normalizeDpr(dpr);
    return _cache.putIfAbsent('user_dot_$d', () => _render(28, 28, d, _paintUserDot));
  }

  static const Offset pinAnchor = Offset(0.5, 1.0);

  Future<BitmapDescriptor> _render(
    double w,
    double h,
    double dpr,
    void Function(Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    paint(canvas);
    final image = await recorder
        .endRecording()
        .toImage((w * dpr).ceil(), (h * dpr).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  // ── Dessins (repère logique 56×56, avant du véhicule vers le haut) ────────

  void _shadow(Canvas c, Rect rect, double radius) {
    c.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 2)), Radius.circular(radius)),
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
  }

  /// Élément sombre cerné de blanc : reste visible sur la carte sombre (#121212).
  void _darkPart(Canvas c, Rect rect, double radius) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    c.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    c.drawRRect(rr, Paint()..color = _ink);
  }

  void _paintCar(Canvas c) {
    const cx = 28.0, cy = 28.0;
    final body = Rect.fromCenter(center: const Offset(cx, cy), width: 22, height: 42);
    _shadow(c, body, 9);
    // Rétroviseurs
    final mirror = Paint()..color = _orangeDark;
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx - 12, 20), width: 3, height: 5),
        const Radius.circular(1.5)), mirror);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx + 12, 20), width: 3, height: 5),
        const Radius.circular(1.5)), mirror);
    // Carrosserie + liseré blanc (lisible sur fond sombre)
    final bodyRR = RRect.fromRectAndRadius(body, const Radius.circular(9));
    c.drawRRect(bodyRR, Paint()..color = _orange);
    c.drawRRect(
      bodyRR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Vitres
    final glass = Paint()..color = _ink.withOpacity(0.88);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 19), width: 15, height: 8),
        const Radius.circular(3)), glass);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 39), width: 15, height: 6),
        const Radius.circular(3)), glass);
    // Toit
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 29), width: 15, height: 9),
        const Radius.circular(3)), Paint()..color = _orangeDark);
    // Feux avant (blancs) / arrière (rouges)
    final head = Paint()..color = Colors.white;
    c.drawOval(Rect.fromCenter(center: const Offset(cx - 5.5, 8.6), width: 4.2, height: 2), head);
    c.drawOval(Rect.fromCenter(center: const Offset(cx + 5.5, 8.6), width: 4.2, height: 2), head);
    final tail = Paint()..color = const Color(0xFFFF3B3B);
    c.drawOval(Rect.fromCenter(center: const Offset(cx - 5.5, 47.4), width: 4.2, height: 2), tail);
    c.drawOval(Rect.fromCenter(center: const Offset(cx + 5.5, 47.4), width: 4.2, height: 2), tail);
  }

  void _paintMoto(Canvas c) {
    const cx = 28.0;
    _shadow(c, Rect.fromCenter(center: const Offset(cx, 28), width: 12, height: 40), 6);
    // Roues
    _darkPart(c, Rect.fromCenter(center: const Offset(cx, 42), width: 5.5, height: 13), 2.7);
    _darkPart(c, Rect.fromCenter(center: const Offset(cx, 14), width: 5.5, height: 12), 2.7);
    // Châssis
    final bodyRR = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 28), width: 10, height: 26),
        const Radius.circular(5));
    c.drawRRect(bodyRR, Paint()..color = _orange);
    c.drawRRect(
      bodyRR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Guidon
    _darkPart(c, Rect.fromCenter(center: const Offset(cx, 18.5), width: 22, height: 3), 1.5);
    // Pilote : épaules + casque
    c.drawOval(Rect.fromCenter(center: const Offset(cx, 30), width: 16, height: 10),
        Paint()..color = _ink);
    c.drawCircle(const Offset(cx, 27), 4.6, Paint()..color = const Color(0xFFFFB27A));
    c.drawCircle(
      const Offset(cx, 27),
      4.6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Phare
    c.drawCircle(const Offset(cx, 8.2), 1.6, Paint()..color = Colors.white);
  }

  void _paintTruck(Canvas c) {
    const cx = 28.0;
    final cab = Rect.fromCenter(center: const Offset(cx, 12.5), width: 20, height: 15);
    final box = Rect.fromCenter(center: const Offset(cx, 34), width: 23, height: 30);
    _shadow(c, Rect.fromLTRB(box.left, cab.top, box.right, box.bottom), 5);
    // Caisse (blanc, contour orange)
    final boxRR = RRect.fromRectAndRadius(box, const Radius.circular(3));
    c.drawRRect(boxRR, Paint()..color = Colors.white);
    c.drawRRect(
      boxRR,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    c.drawLine(const Offset(cx, 22), const Offset(cx, 47),
        Paint()..color = _orange.withOpacity(0.25)..strokeWidth = 1);
    // Cabine
    final cabRR = RRect.fromRectAndRadius(cab, const Radius.circular(5));
    c.drawRRect(cabRR, Paint()..color = _orange);
    c.drawRRect(
      cabRR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, 9.5), width: 14, height: 5),
        const Radius.circular(2)), Paint()..color = _ink.withOpacity(0.88));
    // Rétroviseurs
    _darkPart(c, Rect.fromCenter(center: const Offset(cx - 11.5, 11), width: 3, height: 5), 1.5);
    _darkPart(c, Rect.fromCenter(center: const Offset(cx + 11.5, 11), width: 3, height: 5), 1.5);
    // Feux
    final tail = Paint()..color = const Color(0xFFFF3B3B);
    c.drawOval(Rect.fromCenter(center: const Offset(cx - 6, 48), width: 4.2, height: 2), tail);
    c.drawOval(Rect.fromCenter(center: const Offset(cx + 6, 48), width: 4.2, height: 2), tail);
  }

  void _paintUserDot(Canvas c) {
    const center = Offset(14, 14);
    c.drawCircle(
      center.translate(0, 1),
      10,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    c.drawCircle(center, 9.5, Paint()..color = Colors.white);
    c.drawCircle(center, 6.5, Paint()..color = const Color(0xFF2563EB));
  }

  void _paintPin(Canvas c, bool destination) {
    const cx = 20.0, cy = 20.0, r = 15.0, tipY = 49.0;
    // Ombre au sol
    c.drawOval(
      Rect.fromCenter(center: const Offset(cx, tipY), width: 14, height: 5),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    final head = Path()..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: r));
    final tail = Path()
      ..moveTo(cx - 10, cy + 11)
      ..quadraticBezierTo(cx - 2, cy + 17, cx, tipY)
      ..quadraticBezierTo(cx + 2, cy + 17, cx + 10, cy + 11)
      ..close();
    final pin = Path.combine(PathOperation.union, head, tail);
    c.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(pin, Paint()..color = _orange);
    final white = Paint()..color = Colors.white;
    if (destination) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(cx, cy), width: 12, height: 12),
            const Radius.circular(2.5)),
        white,
      );
    } else {
      c.drawCircle(const Offset(cx, cy), 6, white);
    }
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:atlasmove/map/driver_marker_controller.dart';
import 'package:atlasmove/map/geo_utils.dart';
import 'package:atlasmove/map/map_markers.dart';
import 'package:atlasmove/map/map_styles.dart';
import 'package:atlasmove/map/route_overlay.dart';

DriverFix fix(
  double lat,
  double lng, {
  double? heading,
  double? speed,
  double? accuracy,
  required DateTime at,
}) =>
    DriverFix(
      position: LatLng(lat, lng),
      heading: heading,
      speedMps: speed,
      accuracyM: accuracy,
      timestamp: at,
    );

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  test('les styles de carte sont du JSON valide', () {
    expect(jsonDecode(MapStyles.light), isA<List>());
    expect(jsonDecode(MapStyles.dark), isA<List>());
    expect(MapStyles.dark.contains('#121212'), isTrue);
  });

  test('VehicleCategory déduit la catégorie des slugs de l\'app', () {
    expect(VehicleCategory.fromLabel('coursier_moto'), VehicleCategory.moto);
    expect(VehicleCategory.fromLabel('Moto standard'), VehicleCategory.moto);
    expect(VehicleCategory.fromLabel('camion_10t'), VehicleCategory.truck);
    expect(VehicleCategory.fromLabel('pickup_truck'), VehicleCategory.truck);
    expect(VehicleCategory.fromLabel('taxi_standard'), VehicleCategory.car);
    expect(VehicleCategory.fromLabel(null), VehicleCategory.car);
  });

  group('DriverFixFilter', () {
    test('rejette une précision faible mais tolère le tout premier fix grossier', () {
      final f = DriverFixFilter();
      expect(f.accept(fix(36.8, 10.18, accuracy: 120, at: t0)), isNotNull);
      // fix suivant très imprécis → rejeté
      expect(f.accept(fix(36.8010, 10.18, accuracy: 120, at: t0.add(const Duration(seconds: 5)))), isNull);
      // trop imprécis même relâché
      final g = DriverFixFilter();
      expect(g.accept(fix(36.8, 10.18, accuracy: 400, at: t0)), isNull);
    });

    test('rejette un saut irréaliste puis se ré-ancre après 3 sauts consécutifs', () {
      final f = DriverFixFilter();
      f.accept(fix(36.8000, 10.1800, accuracy: 5, at: t0));
      // ~11 km en 1 s
      final jump = (int s) => fix(36.9000, 10.1800, accuracy: 5, at: t0.add(Duration(seconds: s)));
      expect(f.accept(jump(1)), isNull);
      expect(f.accept(jump(2)), isNull);
      expect(f.accept(jump(3)), isNotNull, reason: 're-sync après 3 sauts');
    });

    test('ignore le jitter < 2 m et les fixes hors-ordre', () {
      final f = DriverFixFilter();
      f.accept(fix(36.80000, 10.18000, accuracy: 5, at: t0));
      expect(f.accept(fix(36.800005, 10.18000, accuracy: 5, at: t0.add(const Duration(seconds: 2)))), isNull);
      expect(f.accept(fix(36.8005, 10.18, accuracy: 5, at: t0.subtract(const Duration(seconds: 1)))), isNull);
      expect(f.accept(fix(36.8005, 10.18, accuracy: 5, at: t0.add(const Duration(seconds: 4)))), isNotNull);
    });

    test('rejette (0,0) et NaN', () {
      final f = DriverFixFilter();
      expect(f.accept(fix(0, 0, at: t0)), isNull);
      expect(f.accept(fix(double.nan, 1, at: t0)), isNull);
    });
  });

  group('GeoUtils', () {
    test('lerpAngle prend le plus court chemin', () {
      expect(GeoUtils.lerpAngle(350, 10, 0.5), closeTo(0, 0.001));
      expect(GeoUtils.lerpAngle(10, 350, 0.5), closeTo(0, 0.001));
      expect(GeoUtils.lerpAngle(90, 180, 0.5), closeTo(135, 0.001));
    });

    test('bearing nord / est', () {
      expect(GeoUtils.bearing(const LatLng(0, 0), const LatLng(1, 0)), closeTo(0, 0.01));
      expect(GeoUtils.bearing(const LatLng(0, 0), const LatLng(0, 1)), closeTo(90, 0.01));
    });
  });

  group('DriverMarkerController', () {
    testWidgets('un seul marqueur à id constant, interpolé sans téléportation', (tester) async {
      final c = DriverMarkerController(vsync: const TestVSync());
      c.setIcon(BitmapDescriptor.defaultMarker);

      expect(c.marker.value, isNull);
      c.update(fix(36.8000, 10.1800, accuracy: 5, speed: 10, heading: 90, at: t0));
      expect(c.marker.value!.markerId, DriverMarkerController.markerId);
      expect(c.marker.value!.position, const LatLng(36.8000, 10.1800));

      c.update(fix(36.8003, 10.1800, accuracy: 5, speed: 10, heading: 0, at: t0.add(const Duration(seconds: 1)))); // ~33 m en 1 s
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final mid = c.marker.value!.position;
      expect(mid.latitude, greaterThan(36.8000));
      expect(mid.latitude, lessThan(36.8003), reason: 'pas de saut direct à la cible');

      await tester.pump(const Duration(seconds: 2));
      expect(c.marker.value!.position.latitude, closeTo(36.8003, 1e-9));
      expect(c.marker.value!.markerId, DriverMarkerController.markerId);
      c.dispose();
    });

    testWidgets('le cap est conservé quand la vitesse est quasi nulle', (tester) async {
      final c = DriverMarkerController(vsync: const TestVSync());
      c.setIcon(BitmapDescriptor.defaultMarker);
      c.update(fix(36.8000, 10.1800, accuracy: 5, speed: 10, heading: 90, at: t0));
      // Déplacement de ~4 m, capteur dit 0.2 m/s, cap bruité à 200° → ignoré
      c.update(fix(36.80003, 10.1800, accuracy: 5, speed: 0.2, heading: 200, at: t0.add(const Duration(seconds: 1))));
      await tester.pump(const Duration(seconds: 3));
      expect(c.bearing, closeTo(90, 0.5));
      c.dispose();
    });

    testWidgets('pas de marqueur tant que l\'icône n\'est pas prête', (tester) async {
      final c = DriverMarkerController(vsync: const TestVSync());
      c.update(fix(36.8, 10.18, accuracy: 5, at: t0));
      expect(c.marker.value, isNull);
      c.setIcon(BitmapDescriptor.defaultMarker);
      expect(c.marker.value, isNotNull);
      c.dispose();
    });
  });

  group('RouteOverlay', () {
    testWidgets('la partie parcourue est retirée du tracé restant', (tester) async {
      final r = RouteOverlay(vsync: const TestVSync());
      // Route rectiligne vers le nord, ~1.1 km
      final pts = [for (var i = 0; i <= 10; i++) LatLng(36.80 + i * 0.001, 10.18)];
      r.setRoute(pts, durationSeconds: 300, animate: false);
      final total = r.totalMeters;
      expect(total, greaterThan(1000));
      expect(r.polylines.value.map((p) => p.polylineId.value), contains('route_main'));
      expect(r.polylines.value.map((p) => p.polylineId.value), isNot(contains('route_done')));

      r.updateProgress(const LatLng(36.8055, 10.18));
      expect(r.remainingMeters, lessThan(total * 0.55));
      expect(r.remainingSeconds!, lessThan(300 * 0.55));
      expect(r.isOffRoute, isFalse);
      expect(r.polylines.value.map((p) => p.polylineId.value), contains('route_done'));

      // Très loin du tracé → hors route, le tracé ne recule pas
      r.updateProgress(const LatLng(36.80, 10.30));
      expect(r.isOffRoute, isTrue);
      r.dispose();
    });
  });
}

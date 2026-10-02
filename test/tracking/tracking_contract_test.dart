import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:atlasmove/providers/ride_state_provider.dart';
import 'package:atlasmove/services/notification_service.dart';
import 'package:atlasmove/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Faux flutter_secure_storage (HttpClient lit le deviceId / token)
  final store = <String, String>{};
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key!] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(store);
        }
        return null;
      },
    );
  });

  group('RideStateNotifier — évènements temps réel', () {
    late RideStateNotifier notifier;

    setUp(() {
      notifier = RideStateNotifier()..startForTrip('trip-1', 'accepted');
    });
    tearDown(() {
      notifier.stopTracking();
      notifier.dispose();
    });

    Map<String, dynamic> loc({String? tripId, double lat = 36.8, bool replay = false}) => {
          if (tripId != null) 'tripId': tripId,
          'latitude': lat,
          'longitude': 10.18,
          'heading': 92,
          'speed': 8.3,
          'accuracy': 12,
          'timestamp': 1760000000000,
          if (replay) 'replay': true,
        };

    test('accepte location.updated de SA course (avec vitesse et précision)', () {
      NotificationService.onDriverLocationReceived!(loc(tripId: 'trip-1'));
      final l = notifier.state.driverLocation!;
      expect(l.position.latitude, 36.8);
      expect(l.heading, 92);
      expect(l.speed, 8.3);
      expect(l.accuracy, 12);
    });

    test('ignore un évènement d\'une autre course', () {
      NotificationService.onDriverLocationReceived!(loc(tripId: 'trip-2'));
      expect(notifier.state.driverLocation, isNull);
    });

    test('ignore un évènement SANS tripId (le client ne doit voir que son chauffeur)', () {
      NotificationService.onDriverLocationReceived!(loc());
      expect(notifier.state.driverLocation, isNull);
    });

    test('affiche immédiatement la position rejouée (replay: true) à la reconnexion', () {
      NotificationService.onDriverLocationReceived!(loc(tripId: 'trip-1', replay: true));
      expect(notifier.state.driverLocation, isNotNull);
    });

    test('nouveau statut « arrived » et statuts inconnus sans plantage', () {
      NotificationService.onTripStatusReceived!({'tripId': 'trip-1', 'status': 'arrived'});
      expect(notifier.state.status, RideStatus.arrived);
      expect(notifier.state.isActive, isTrue);

      NotificationService.onTripStatusReceived!({'tripId': 'trip-1', 'status': 'un_statut_futur'});
      expect(notifier.state.status, RideStatus.unknown);

      NotificationService.onTripStatusReceived!({'tripId': 'trip-1', 'status': 'in_progress'});
      expect(notifier.state.status, RideStatus.inProgress);
    });
  });

  group('TripService.getDriverLocation — codes d\'erreur du backend', () {
    Future<T> withReply<T>(int status, String body, Future<T> Function() run) => http.runWithClient(
          run,
          () => MockClient((_) async => http.Response(body, status)),
        );

    test('200 : lit latitude / longitude / vitesse / précision', () async {
      final dto = await withReply(
        200,
        '{"message":"ok","data":{"tripId":"t","latitude":36.8,"longitude":10.18,"heading":92,"speed":8.3,"accuracy":12,"timestamp":1}}',
        () => TripService.getDriverLocation('t'),
      );
      expect(dto!.latitude, 36.8);
      expect(dto.speed, 8.3);
      expect(dto.accuracy, 12);
    });

    test('404 driver_location_unavailable → null (on continue de sonder)', () async {
      final dto = await withReply(
        404,
        '{"statusCode":404,"message":"x","code":"driver_location_unavailable","error":{"code":"driver_location_unavailable"}}',
        () => TripService.getDriverLocation('t'),
      );
      expect(dto, isNull);
    });

    test('409 trip_not_active → TripNotActiveException (on ARRÊTE de sonder)', () async {
      await withReply(
        409,
        '{"statusCode":409,"message":"x","code":"trip_not_active","error":{"code":"trip_not_active"}}',
        () async {
          await expectLater(TripService.getDriverLocation('t'), throwsA(isA<TripNotActiveException>()));
        },
      );
    });

    test('403 / 500 / réseau → null, jamais d\'exception', () async {
      expect(await withReply(403, '{"code":"forbidden"}', () => TripService.getDriverLocation('t')), isNull);
      expect(await withReply(500, '{"message":"boom"}', () => TripService.getDriverLocation('t')), isNull);
    });
  });
}

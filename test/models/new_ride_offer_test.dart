import 'package:flutter_test/flutter_test.dart';
import 'package:atlasmove/models/new_ride_offer.dart';

void main() {
  group('NewRideOffer.fromJson', () {
    test('parse un payload FCM (toutes les valeurs en chaînes, tripId snake_case)', () {
      final now = DateTime.now().add(const Duration(seconds: 30));
      final offer = NewRideOffer.fromJson({
        'type': 'new_ride',
        'trip_id': 'trip-123',
        'pickup_address': 'Avenue Habib Bourguiba',
        'destination_address': 'Aéroport Tunis-Carthage',
        'offered_fare': '12.5',
        'currency': 'TND',
        'distance_km': '4.2',
        'service_name': 'Taxi standard',
        'expires_at': now.millisecondsSinceEpoch.toString(),
        'stops_count': '1',
      });

      expect(offer.tripId, 'trip-123');
      expect(offer.pickupAddress, 'Avenue Habib Bourguiba');
      expect(offer.destinationAddress, 'Aéroport Tunis-Carthage');
      expect(offer.offeredFare, 12.5);
      expect(offer.currency, 'TND');
      expect(offer.distanceKm, 4.2);
      expect(offer.stopsCount, 1);
      expect(offer.remaining!.inSeconds, greaterThan(25));
    });

    test('parse un payload socket (tripId camelCase, expires_at en ms epoch)', () {
      final offer = NewRideOffer.fromJson({
        'tripId': 'trip-456',
        'pickup_address': 'Centre-ville',
        'currency': 'TND',
        'expires_at': DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch.toString(),
      });

      expect(offer.tripId, 'trip-456');
      expect(offer.destinationAddress, isNull);
      expect(offer.offeredFare, isNull);
      // Offre déjà expirée → durée restante nulle, jamais négative
      expect(offer.remaining, Duration.zero);
    });

    test('champs numériques absents ou invalides → null plutôt qu\'une exception', () {
      final offer = NewRideOffer.fromJson({'tripId': 't', 'pickup_address': 'x'});
      expect(offer.offeredFare, isNull);
      expect(offer.distanceKm, isNull);
      expect(offer.expiresAt, isNull);
      expect(offer.remaining, isNull);
      expect(offer.currency, 'TND'); // valeur par défaut du contrat backend
    });
  });
}

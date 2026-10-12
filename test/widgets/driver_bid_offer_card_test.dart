import 'dart:async';

import 'package:atlasmove/models/trip_models.dart';
import 'package:atlasmove/widgets/driver_bid_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidOffer _offer(Map<String, dynamic> extra) => BidOffer.fromJson({
      'id': 'o1',
      'trip_id': 't1',
      'driver_name': 'Karim Ben Ali',
      'proposed_fare': '12.5',
      'status': 'pending',
      ...extra,
    });

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('BidOffer — données réellement reçues', () {
    test('note et véhicule absents : champs « reported » à null, défauts conservés', () {
      final o = _offer({});
      expect(o.reportedRating, isNull);
      expect(o.reportedVehicle, isNull);
      // Comportement historique inchangé pour les autres écrans.
      expect(o.driverRating, 4.8);
      expect(o.driverVehicle, 'Moto standard');
    });

    test('note et véhicule présents : repris tels quels', () {
      final o = _offer({'driver_rating': '4.6', 'driver_vehicle': ' Peugeot 208 '});
      expect(o.reportedRating, 4.6);
      expect(o.reportedVehicle, 'Peugeot 208');
    });
  });

  group('DriverBidOfferCard', () {
    testWidgets("n'affiche ni note ni véhicule inventés", (tester) async {
      await tester.pumpWidget(_wrap(DriverBidOfferCard(
        offer: _offer({}),
        currency: 'TND',
        onReject: () async {},
        onCounter: () {},
        onAccept: () async {},
      )));
      expect(find.text('Karim Ben Ali'), findsOneWidget);
      expect(find.text('12.50 TND'), findsOneWidget);
      expect(find.text('4.8'), findsNothing);
      expect(find.text('Moto standard'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('affiche note et véhicule quand le backend les envoie', (tester) async {
      await tester.pumpWidget(_wrap(DriverBidOfferCard(
        offer: _offer({'driver_rating': 4.6, 'driver_vehicle': 'Peugeot 208'}),
        currency: 'TND',
        onReject: () async {},
        onCounter: () {},
        onAccept: () async {},
      )));
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('Peugeot 208'), findsOneWidget);
    });

    testWidgets('accepter : un seul appel, boutons bloqués pendant l\'action', (tester) async {
      final completer = Completer<void>();
      var accepts = 0;
      var rejects = 0;
      await tester.pumpWidget(_wrap(DriverBidOfferCard(
        offer: _offer({}),
        currency: 'TND',
        onReject: () async => rejects++,
        onCounter: () {},
        onAccept: () {
          accepts++;
          return completer.future;
        },
      )));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Double tap et refus ignorés tant que l'acceptation est en cours.
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
      await tester.pump();
      expect(accepts, 1);
      expect(rejects, 0);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

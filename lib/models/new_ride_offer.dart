/// Offre de course reçue par le chauffeur, via push FCM (`type: "new_ride"`,
/// toutes les valeurs en chaînes) ou évènement socket `new_ride` (mêmes clés,
/// plus `tripId`). Les deux sources sont acceptées par [fromJson].
class NewRideOffer {
  final String tripId;
  final String pickupAddress;
  final String? destinationAddress;
  final double? offeredFare;
  final String currency;
  final double? distanceKm;
  final String? serviceName;
  final DateTime? expiresAt;
  final int stopsCount;

  const NewRideOffer({
    required this.tripId,
    required this.pickupAddress,
    this.destinationAddress,
    this.offeredFare,
    required this.currency,
    this.distanceKm,
    this.serviceName,
    this.expiresAt,
    this.stopsCount = 0,
  });

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  static DateTime? _epochMs(dynamic v) {
    final n = v == null ? null : int.tryParse(v.toString());
    return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n);
  }

  factory NewRideOffer.fromJson(Map<String, dynamic> json) => NewRideOffer(
        tripId: (json['tripId'] ?? json['trip_id']).toString(),
        pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? '').toString(),
        destinationAddress: json['destination_address']?.toString(),
        offeredFare: _num(json['offered_fare']),
        currency: (json['currency'] ?? 'TND').toString(),
        distanceKm: _num(json['distance_km']),
        serviceName: json['service_name']?.toString(),
        expiresAt: _epochMs(json['expires_at']),
        stopsCount: int.tryParse(json['stops_count']?.toString() ?? '') ?? 0,
      );

  Duration? get remaining {
    final exp = expiresAt;
    if (exp == null) return null;
    final d = exp.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'offered_fare': offeredFare?.toString(),
        'currency': currency,
        'distance_km': distanceKm?.toString(),
        'service_name': serviceName,
        'expires_at': expiresAt?.millisecondsSinceEpoch.toString(),
        'stops_count': stopsCount.toString(),
      };
}

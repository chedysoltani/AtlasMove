import 'dart:math';

class FareCalculator {
  // Haversine formula — distance in km between two GPS points
  static double distanceKm(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  // Universal fare formula — all values come from the Service model (never hardcoded)
  // pricingModel values: 'fixed' | 'distance' | 'hourly' | 'combined'
  static double calculateFare({
    required String pricingModel,
    required double distanceKm,
    required double durationMin,
    double basePrice = 0,
    double pricePerKm = 0,
    double pricePerMinute = 0,
    double minimumFare = 0,
  }) {
    double fare;
    switch (pricingModel) {
      case 'fixed':
        return basePrice;
      case 'distance': // per km
        fare = basePrice + distanceKm * pricePerKm;
      case 'hourly': // per hour (uses pricePerMinute field from API)
        fare = durationMin * pricePerMinute;
      case 'combined':
      default:
        fare = basePrice + distanceKm * pricePerKm + durationMin * pricePerMinute;
    }
    return fare < minimumFare ? minimumFare : fare;
  }

  // Human-readable label for the pricing model
  static String pricingModelLabel(String pricingModel) {
    switch (pricingModel) {
      case 'fixed':    return 'Prix fixe';
      case 'distance': return 'Au kilomètre';
      case 'hourly':   return 'À l\'heure';
      case 'combined': return 'Base + km + temps';
      default:         return pricingModel;
    }
  }

  // Short badge label
  static String pricingModelBadge(String pricingModel) {
    switch (pricingModel) {
      case 'fixed':    return 'Fixe';
      case 'distance': return '/km';
      case 'hourly':   return '/h';
      case 'combined': return 'Combiné';
      default:         return pricingModel;
    }
  }

  // Format a fare amount with its currency
  static String formatFare(double amount, String currency) {
    return '${amount.toStringAsFixed(3)} $currency';
  }

  // Estimated duration for a given distance (30 km/h average for delivery)
  static double estimatedDurationMin(double distanceKm, {double avgSpeedKmh = 30}) {
    return (distanceKm / avgSpeedKmh) * 60;
  }
}

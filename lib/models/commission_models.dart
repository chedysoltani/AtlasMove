import '../models/service_models.dart';
import 'package:easy_localization/easy_localization.dart';

class CommissionBreakdownItem {
  final String? serviceId;
  final String? billingModel;
  final String serviceName;
  final String transportType;
  final int completedCount;
  final double revenue;
  final double commission;
  final String currency;

  const CommissionBreakdownItem({
    this.serviceId,
    this.billingModel,
    required this.serviceName,
    required this.transportType,
    required this.completedCount,
    required this.revenue,
    required this.commission,
    required this.currency,
  });

  /// Service à l'abonnement (Taxi Économique) : exempté de la commission 10 %.
  /// Sans `billing_model` ni `service_id` dans la réponse, on se fie au montant
  /// calculé par le backend (commission nulle sur un CA non nul).
  bool get isSubscriptionService {
    if ((billingModel ?? '').isNotEmpty || (serviceId ?? '').isNotEmpty) {
      return BillingRule.isSubscription(billingModel: billingModel, serviceId: serviceId);
    }
    return revenue > 0 && commission <= 0;
  }

  factory CommissionBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CommissionBreakdownItem(
      serviceId: json['service_id']?.toString(),
      billingModel: json['billing_model']?.toString(),
      serviceName: json['service_name']?.toString() ?? '',
      transportType: json['transport_type']?.toString() ?? '',
      completedCount: int.tryParse(json['completed_count']?.toString() ?? '0') ?? 0,
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
    );
  }
}

class DriverCommissionStats {
  final String period; // "2026-06"
  final double totalRevenue;
  final String currency;
  final double commissionRate; // 0.10
  final double commissionDue;
  final bool commissionPaid;
  final int completedCount;
  final List<CommissionBreakdownItem> breakdown;

  const DriverCommissionStats({
    required this.period,
    required this.totalRevenue,
    required this.currency,
    required this.commissionRate,
    required this.commissionDue,
    required this.commissionPaid,
    required this.completedCount,
    required this.breakdown,
  });

  String get formattedPeriod {
    final parts = period.split('-');
    if (parts.length != 2) return period;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return period;
    // Mois dans la langue de l'app (Intl.defaultLocale, voir main.dart)
    final label = DateFormat('MMMM yyyy').format(DateTime(year, month));
    return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
  }

  factory DriverCommissionStats.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['breakdown'] as List? ?? [];
    return DriverCommissionStats(
      period: json['period']?.toString() ?? '',
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '0.10') ?? 0.10,
      commissionDue: double.tryParse(json['commission_due']?.toString() ?? '0') ?? 0,
      commissionPaid: json['commission_paid'] == true,
      completedCount: int.tryParse(json['completed_count']?.toString() ?? '0') ?? 0,
      breakdown: rawBreakdown
          .map((j) => CommissionBreakdownItem.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }

  // Used while backend is not ready — builds stats from a list of rendezvous
  factory DriverCommissionStats.fromRendezvousList(
    List<dynamic> rdvList,
    String period,
    String currency,
  ) {
    final Map<String, CommissionBreakdownItem> map = {};
    double total = 0;

    for (final rdv in rdvList) {
      if (rdv.status != 'completed') continue;
      final fare = (rdv.finalFare ?? rdv.estimatedFare ?? 0.0) as double;
      if (fare <= 0) continue;
      final type = (rdv.serviceTransportType ?? '') as String;
      // Taxi Économique : à l'abonnement, pas de commission
      if (BillingRule.isSubscription(serviceId: rdv.serviceId as String?)) continue;

      total += fare;
      final key = rdv.serviceId as String;
      final existing = map[key];
      if (existing != null) {
        map[key] = CommissionBreakdownItem(
          serviceId: key,
          serviceName: existing.serviceName,
          transportType: existing.transportType,
          completedCount: existing.completedCount + 1,
          revenue: existing.revenue + fare,
          commission: (existing.revenue + fare) * BillingRule.commissionRate,
          currency: currency,
        );
      } else {
        map[key] = CommissionBreakdownItem(
          serviceId: key,
          serviceName: rdv.serviceName as String,
          transportType: type,
          completedCount: 1,
          revenue: fare,
          commission: fare * BillingRule.commissionRate,
          currency: currency,
        );
      }
    }

    return DriverCommissionStats(
      period: period,
      totalRevenue: total,
      currency: currency,
      commissionRate: 0.10,
      commissionDue: total * 0.10,
      commissionPaid: false,
      completedCount: map.values.fold(0, (s, i) => s + i.completedCount),
      breakdown: map.values.toList(),
    );
  }
}

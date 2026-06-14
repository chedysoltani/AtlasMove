import '../models/service_models.dart';

class CommissionPaymentInfo {
  final String walletAddress;
  final String network;
  final double amount;
  final String currency;
  final String month;
  final bool commissionPaid;

  const CommissionPaymentInfo({
    required this.walletAddress,
    required this.network,
    required this.amount,
    required this.currency,
    required this.month,
    required this.commissionPaid,
  });

  factory CommissionPaymentInfo.fromJson(Map<String, dynamic> json) {
    return CommissionPaymentInfo(
      walletAddress: json['wallet_address']?.toString() ?? '',
      network: json['network']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
      month: json['month']?.toString() ?? '',
      commissionPaid: json['commission_paid'] == true,
    );
  }
}

class CommissionPaymentRecord {
  final String id;
  final String month;
  final double amount;
  final String currency;
  final String transactionHash;
  final String status; // "pending_verification" | "paid" | "rejected"
  final DateTime? paidAt;

  const CommissionPaymentRecord({
    required this.id,
    required this.month,
    required this.amount,
    required this.currency,
    required this.transactionHash,
    required this.status,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending_verification';
  bool get isRejected => status == 'rejected';

  factory CommissionPaymentRecord.fromJson(Map<String, dynamic> json) {
    return CommissionPaymentRecord(
      id: json['id']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'TND',
      transactionHash: json['transaction_hash']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_verification',
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
    );
  }
}

class CommissionBreakdownItem {
  final String serviceName;
  final String transportType;
  final int completedCount;
  final double revenue;
  final double commission;
  final String currency;

  const CommissionBreakdownItem({
    required this.serviceName,
    required this.transportType,
    required this.completedCount,
    required this.revenue,
    required this.commission,
    required this.currency,
  });

  bool get isTaxiType => TransportTypeConstants.taxiSlugs.contains(transportType);

  factory CommissionBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CommissionBreakdownItem(
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
    final months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    return '${months[month]} ${parts[0]}';
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
      if (TransportTypeConstants.taxiSlugs.contains(type)) continue;

      total += fare;
      final key = rdv.serviceId as String;
      final existing = map[key];
      if (existing != null) {
        map[key] = CommissionBreakdownItem(
          serviceName: existing.serviceName,
          transportType: existing.transportType,
          completedCount: existing.completedCount + 1,
          revenue: existing.revenue + fare,
          commission: (existing.revenue + fare) * 0.10,
          currency: currency,
        );
      } else {
        map[key] = CommissionBreakdownItem(
          serviceName: rdv.serviceName as String,
          transportType: type,
          completedCount: 1,
          revenue: fare,
          commission: fare * 0.10,
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

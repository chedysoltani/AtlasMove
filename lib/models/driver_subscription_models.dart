class DriverSubscription {
  final String id;
  final String status; // trial, active, past_due, canceled
  final String amount;
  final String currency;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool cancelAtPeriodEnd;

  const DriverSubscription({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.startedAt,
    required this.expiresAt,
    required this.cancelAtPeriodEnd,
  });

  factory DriverSubscription.fromJson(Map<String, dynamic> json) {
    return DriverSubscription(
      id: json['id'] ?? '',
      status: json['status'] ?? 'canceled',
      amount: json['amount'] ?? '90.00',
      currency: json['currency'] ?? 'USD',
      startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
    );
  }

  bool get isActive => status == 'active';
  bool get isTrial => status == 'trial';
  bool get isPastDue => status == 'past_due';
  bool get isCanceled => status == 'canceled';
  bool get isValid => (isActive || isTrial) && expiresAt.isAfter(DateTime.now());

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }
}

class LoyaltyProgram {
  final String id;
  final String accruedCashback;
  final int completedTripsCount;
  final bool isCompleted;

  const LoyaltyProgram({
    required this.id,
    required this.accruedCashback,
    required this.completedTripsCount,
    required this.isCompleted,
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> json) {
    return LoyaltyProgram(
      id: json['id'] ?? '',
      accruedCashback: json['accrued_cashback'] ?? '0.00',
      completedTripsCount: json['completed_trips_count'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
    );
  }

  double get cashbackAmount => double.tryParse(accruedCashback) ?? 0.0;

  // 100 USD cashback target over the loyalty period
  static const double targetCashback = 100.0;
  double get progressPercent => (cashbackAmount / targetCashback).clamp(0.0, 1.0);
}

class DriverSubscriptionStatus {
  final bool hasActiveSubscription;
  final DriverSubscription? subscription;
  final LoyaltyProgram? loyaltyProgram;

  const DriverSubscriptionStatus({
    required this.hasActiveSubscription,
    this.subscription,
    this.loyaltyProgram,
  });

  factory DriverSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return DriverSubscriptionStatus(
      hasActiveSubscription: json['has_active_subscription'] ?? false,
      subscription: json['subscription'] != null
          ? DriverSubscription.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
      loyaltyProgram: json['loyalty_program'] != null
          ? LoyaltyProgram.fromJson(json['loyalty_program'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─── Programme Privilège Dashboard ──────────────────────────────────────────

class PrivilegeStats {
  final int completedTripsThisMonth;
  final int monthlyConsecutiveMonths;
  final String currentLevel;

  const PrivilegeStats({
    required this.completedTripsThisMonth,
    required this.monthlyConsecutiveMonths,
    required this.currentLevel,
  });

  factory PrivilegeStats.fromJson(Map<String, dynamic> json) {
    return PrivilegeStats(
      completedTripsThisMonth: int.tryParse(json['completedTripsThisMonth']?.toString() ?? '0') ?? 0,
      monthlyConsecutiveMonths: int.tryParse(json['monthlyConsecutiveMonths']?.toString() ?? '0') ?? 0,
      currentLevel: json['currentLevel']?.toString() ?? 'bronze',
    );
  }
}

class PrivilegeMonthlyObjective {
  final int targetTrips;
  final int completedTrips;
  final int remainingTrips;
  final int targetHours;
  final int completedHours;
  final int remainingHours;
  final double completionPercentage;
  final String helperMessage;

  const PrivilegeMonthlyObjective({
    required this.targetTrips,
    required this.completedTrips,
    required this.remainingTrips,
    required this.targetHours,
    required this.completedHours,
    required this.remainingHours,
    required this.completionPercentage,
    required this.helperMessage,
  });

  factory PrivilegeMonthlyObjective.fromJson(Map<String, dynamic> json) {
    return PrivilegeMonthlyObjective(
      targetTrips: int.tryParse(json['targetTrips']?.toString() ?? '0') ?? 0,
      completedTrips: int.tryParse(json['completedTrips']?.toString() ?? '0') ?? 0,
      remainingTrips: int.tryParse(json['remainingTrips']?.toString() ?? '0') ?? 0,
      targetHours: (double.tryParse(json['targetHours']?.toString() ?? '0') ?? 0.0).round(),
      completedHours: (double.tryParse(json['completedHours']?.toString() ?? '0') ?? 0.0).round(),
      remainingHours: (double.tryParse(json['remainingHours']?.toString() ?? '0') ?? 0.0).round(),
      completionPercentage: double.tryParse(json['completionPercentage']?.toString() ?? '0') ?? 0.0,
      helperMessage: json['helperMessage']?.toString() ?? '',
    );
  }
}

class PrivilegeFinancials {
  final double totalSpentSubscriptions;
  final String currency;
  final double commissionRate;
  final int totalTripsCompleted;
  final double totalCommissionPaid;
  final double totalDriverEarnings;

  const PrivilegeFinancials({
    required this.totalSpentSubscriptions,
    required this.currency,
    required this.commissionRate,
    required this.totalTripsCompleted,
    required this.totalCommissionPaid,
    required this.totalDriverEarnings,
  });

  factory PrivilegeFinancials.fromJson(Map<String, dynamic> json) {
    return PrivilegeFinancials(
      totalSpentSubscriptions: double.tryParse(json['totalSpentSubscriptions']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      commissionRate: double.tryParse(json['commissionRate']?.toString() ?? '0') ?? 0.0,
      totalTripsCompleted: int.tryParse(json['totalTripsCompleted']?.toString() ?? '0') ?? 0,
      totalCommissionPaid: double.tryParse(json['totalCommissionPaid']?.toString() ?? '0') ?? 0.0,
      totalDriverEarnings: double.tryParse(json['totalDriverEarnings']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class PrivilegeReward {
  final String id;
  final String title;
  final String subtitle;
  final String type; // cashback | travel
  final int targetMonths;
  final int completedMonths;
  final int remainingMonths;
  final double completionPercentage;
  final String status;

  const PrivilegeReward({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.targetMonths,
    required this.completedMonths,
    required this.remainingMonths,
    required this.completionPercentage,
    required this.status,
  });

  factory PrivilegeReward.fromJson(Map<String, dynamic> json) {
    return PrivilegeReward(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      type: json['type']?.toString() ?? 'cashback',
      targetMonths: int.tryParse(json['targetMonths']?.toString() ?? '0') ?? 0,
      completedMonths: int.tryParse(json['completedMonths']?.toString() ?? '0') ?? 0,
      remainingMonths: int.tryParse(json['remainingMonths']?.toString() ?? '0') ?? 0,
      completionPercentage: double.tryParse(json['completionPercentage']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'in_progress',
    );
  }
}

class PrivilegeDashboard {
  final String vipLevel;
  final int score;
  final int streakMonths;
  final PrivilegeStats stats;
  final PrivilegeMonthlyObjective monthlyObjective;
  final PrivilegeFinancials financials;
  final List<PrivilegeReward> rewards;

  const PrivilegeDashboard({
    required this.vipLevel,
    required this.score,
    required this.streakMonths,
    required this.stats,
    required this.monthlyObjective,
    required this.financials,
    required this.rewards,
  });

  factory PrivilegeDashboard.fromJson(Map<String, dynamic> json) {
    final rewardsList = (json['rewards'] as List?)
            ?.map((r) => PrivilegeReward.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    return PrivilegeDashboard(
      vipLevel: json['vip_level']?.toString() ?? 'silver',
      score: int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      streakMonths: int.tryParse(json['streak_months']?.toString() ?? '0') ?? 0,
      stats: json['stats'] != null
          ? PrivilegeStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const PrivilegeStats(completedTripsThisMonth: 0, monthlyConsecutiveMonths: 0, currentLevel: 'bronze'),
      monthlyObjective: json['monthlyObjective'] != null
          ? PrivilegeMonthlyObjective.fromJson(json['monthlyObjective'] as Map<String, dynamic>)
          : const PrivilegeMonthlyObjective(
              targetTrips: 0, completedTrips: 0, remainingTrips: 0,
              targetHours: 0, completedHours: 0, remainingHours: 0,
              completionPercentage: 0, helperMessage: ''),
      financials: json['financials'] != null
          ? PrivilegeFinancials.fromJson(json['financials'] as Map<String, dynamic>)
          : const PrivilegeFinancials(
              totalSpentSubscriptions: 0, currency: 'USD', commissionRate: 0,
              totalTripsCompleted: 0, totalCommissionPaid: 0, totalDriverEarnings: 0),
      rewards: rewardsList,
    );
  }
}

// ─── Client Loyalty Milestones ────────────────────────────────────────────────

class ClientLoyaltyProgram {
  final String id;
  final String type; // client_cashback_6m | client_travel_12m
  final String title;
  final String startedAt;
  final String lastEvaluatedAt;
  final int totalTrips;
  final double cashbackAccrued;
  final String status;
  final int targetTrips;

  const ClientLoyaltyProgram({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.lastEvaluatedAt,
    required this.totalTrips,
    required this.cashbackAccrued,
    required this.status,
    required this.targetTrips,
  });

  factory ClientLoyaltyProgram.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    return ClientLoyaltyProgram(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      startedAt: json['started_at']?.toString() ?? '',
      lastEvaluatedAt: json['last_evaluated_at']?.toString() ?? '',
      totalTrips: int.tryParse(progress['total_trips']?.toString() ?? '0') ?? 0,
      cashbackAccrued: double.tryParse(json['cashback_accrued']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'active',
      targetTrips: int.tryParse(json['target_trips']?.toString() ?? '0') ?? 0,
    );
  }

  int get remainingTrips => (targetTrips - totalTrips).clamp(0, targetTrips);
  double get progressPercent =>
      targetTrips > 0 ? (totalTrips / targetTrips).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => status == 'completed' || totalTrips >= targetTrips;
}

class ClientLoyaltyStatus {
  final List<ClientLoyaltyProgram> activePrograms;

  const ClientLoyaltyStatus({required this.activePrograms});

  factory ClientLoyaltyStatus.fromJson(Map<String, dynamic> json) {
    final list = (json['active_programs'] as List?) ?? [];
    return ClientLoyaltyStatus(
      activePrograms: list
          .map((p) => ClientLoyaltyProgram.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  ClientLoyaltyProgram? get cashbackProgram =>
      activePrograms.cast<ClientLoyaltyProgram?>().firstWhere(
            (p) => p?.type == 'client_cashback_6m',
            orElse: () => null,
          );

  ClientLoyaltyProgram? get travelProgram =>
      activePrograms.cast<ClientLoyaltyProgram?>().firstWhere(
            (p) => p?.type == 'client_travel_12m',
            orElse: () => null,
          );
}

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
    // Dépaqueter l'enveloppe data si présente (format standard API)
    final data = (json['data'] is Map ? json['data'] as Map<String, dynamic> : null) ?? json;
    return DriverSubscriptionStatus(
      hasActiveSubscription: data['has_active_subscription'] ?? false,
      subscription: data['subscription'] != null
          ? DriverSubscription.fromJson(data['subscription'] as Map<String, dynamic>)
          : null,
      loyaltyProgram: data['loyalty_program'] != null
          ? LoyaltyProgram.fromJson(data['loyalty_program'] as Map<String, dynamic>)
          : null,
    );
  }
}

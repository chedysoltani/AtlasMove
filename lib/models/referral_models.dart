class ReferralItem {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime createdAt;
  final bool isReferralCompleted;

  const ReferralItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.createdAt,
    required this.isReferralCompleted,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isReferralCompleted: json['is_referral_completed'] ?? false,
    );
  }

  String get fullName => '$firstName $lastName';
}

class ReferralData {
  final String referralCode;
  final int totalReferred;
  final int totalCompleted;
  final int pointsEarned;
  final List<ReferralItem> referrals;

  const ReferralData({
    required this.referralCode,
    required this.totalReferred,
    required this.totalCompleted,
    required this.pointsEarned,
    required this.referrals,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ReferralData(
      referralCode: data['referral_code'] ?? '',
      totalReferred: data['total_referred'] ?? 0,
      totalCompleted: data['total_completed'] ?? 0,
      pointsEarned: data['points_earned'] ?? 0,
      referrals: (data['referrals'] as List<dynamic>? ?? [])
          .map((e) => ReferralItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

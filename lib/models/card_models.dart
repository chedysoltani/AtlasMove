class CardDto {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String funding;
  final String? country;
  final String? nickname;
  final bool isDefault;
  final bool isExpired;
  final String maskedLabel;
  final String expiryLabel;
  final DateTime createdAt;

  CardDto({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.funding,
    this.country,
    this.nickname,
    required this.isDefault,
    required this.isExpired,
    required this.maskedLabel,
    required this.expiryLabel,
    required this.createdAt,
  });

  factory CardDto.fromJson(Map<String, dynamic> json) {
    return CardDto(
      id: json['id'],
      brand: json['brand'],
      last4: json['last4'],
      expMonth: json['exp_month'],
      expYear: json['exp_year'],
      funding: json['funding'],
      country: json['country'],
      nickname: json['nickname'],
      isDefault: json['is_default'],
      isExpired: json['is_expired'],
      maskedLabel: json['masked_label'],
      expiryLabel: json['expiry_label'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

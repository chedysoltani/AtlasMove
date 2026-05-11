class PaymentResponseDto {
  final String id;
  final String tripId;
  final String payerId;
  final String paymentType; // "card" | "cash"
  final double amount;
  final double amountRefunded;
  final String currency;
  final String status;
  final String? failureMessage;
  final String? failureCode;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final List<dynamic> refunds;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentResponseDto({
    required this.id,
    required this.tripId,
    required this.payerId,
    required this.paymentType,
    required this.amount,
    required this.amountRefunded,
    required this.currency,
    required this.status,
    this.failureMessage,
    this.failureCode,
    this.paidAt,
    this.failedAt,
    required this.refunds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentResponseDto.fromJson(Map<String, dynamic> json) {
    return PaymentResponseDto(
      id: json['id'],
      tripId: json['trip_id'],
      payerId: json['payer_id'],
      paymentType: json['payment_type'],
      amount: (json['amount'] as num).toDouble(),
      amountRefunded: (json['amount_refunded'] as num).toDouble(),
      currency: json['currency'],
      status: json['status'],
      failureMessage: json['failure_message'],
      failureCode: json['failure_code'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      failedAt: json['failed_at'] != null ? DateTime.parse(json['failed_at']) : null,
      refunds: json['refunds'] ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class PaymentHistoryResponse {
  final List<PaymentResponseDto> data;
  final int total;
  final int page;
  final int limit;

  PaymentHistoryResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    // Le backend renvoie { "data": { "data": [], "total": 0, ... } }
    final payload = json['data'] as Map<String, dynamic>;
    final list = payload['data'] as List;
    
    return PaymentHistoryResponse(
      data: list.map((e) => PaymentResponseDto.fromJson(e)).toList(),
      total: payload['total'] ?? 0,
      page: payload['page'] ?? 1,
      limit: payload['limit'] ?? 20,
    );
  }
}

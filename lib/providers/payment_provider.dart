import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';
import '../models/payment_models.dart';

class PaymentStatusNotifier extends StateNotifier<List<PaymentResponseDto>> {
  PaymentStatusNotifier() : super([]);

  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPolls = 10; // 30 seconds total (every 3s)

  void startPolling() {
    _pollCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_pollCount >= _maxPolls) {
        stopPolling();
        return;
      }

      final processingPayments = await PaymentService.getProcessingPayments();
      state = processingPayments;

      if (processingPayments.isEmpty) {
        // Check for pending payments (3DS)
        final history = await PaymentService.getPaymentHistory(limit: 5);
        if (history != null) {
          final pending3DS = history.data.where((p) => p.status == 'pending' && p.paymentType == 'card').toList();
          if (pending3DS.isNotEmpty) {
            state = pending3DS;
            stopPolling(); // Stop polling to handle 3DS
          }
        }
      }

      _pollCount++;
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> handle3DS(String paymentId) async {
    final clientSecret = await PaymentService.getConfirmClientSecret(paymentId);
    if (clientSecret != null) {
      await PaymentService.handle3DSConfirmation(clientSecret);
      // Restart polling to check for success
      startPolling();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final paymentStatusProvider = StateNotifierProvider<PaymentStatusNotifier, List<PaymentResponseDto>>((ref) {
  return PaymentStatusNotifier();
});

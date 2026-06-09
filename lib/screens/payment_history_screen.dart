import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../models/payment_models.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<PaymentResponseDto> _payments = [];
  int _total = 0;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final response = await PaymentService.getPaymentHistory(page: _page);
    if (mounted && response != null) {
      setState(() {
        _payments = response.data;
        _total = response.total;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('payment.history_title'.tr()),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _payments.isEmpty 
                  ? Center(child: Text('common.no_data'.tr()))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        return _buildPaymentCard(payment);
                      },
                    ),
            ),
    );
  }

  Widget _buildPaymentCard(PaymentResponseDto payment) {
    final bool isFailed = payment.status == 'failed';
    final bool isCard = payment.paymentType == 'card';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            _buildStatusIcon(payment.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(payment.status),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('ID Transaction', payment.id), // TODO: add translation key for "ID Transaction"
                _buildInfoRow('ID Course', payment.tripId), // TODO: add translation key for "ID Course"
                _buildInfoRow('payment.method'.tr(), isCard ? 'payment.cards_title'.tr() : 'common.no_data'.tr()), // TODO: add translation key for "Carte" / "Espèces"
                if (payment.failureMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Erreur: ${payment.failureMessage}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                if (isFailed && isCard)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleRetry(payment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('common.retry'.tr()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'succeeded':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'failed':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'processing':
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 24);
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'succeeded':
        color = Colors.green;
        label = 'common.completed'.tr();
        break;
      case 'failed':
        color = Colors.red;
        label = 'common.cancelled'.tr(); // TODO: add translation key for "Échoué"
        break;
      case 'processing':
        color = Colors.blue;
        label = 'common.loading'.tr(); // TODO: add translation key for "Traitement"
        break;
      case 'pending':
        color = Colors.orange;
        label = 'common.pending'.tr();
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _handleRetry(PaymentResponseDto payment) async {
    final result = await PaymentService.retryPayment(payment.id);
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.loading'.tr()), backgroundColor: Colors.blue), // TODO: add translation key for "Tentative de paiement en cours..."
      );
      _loadHistory();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.unknown_error'.tr()), backgroundColor: Colors.red), // TODO: add translation key for "Erreur lors de la tentative de paiement"
      );
    }
  }
}

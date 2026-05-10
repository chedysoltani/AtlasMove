import 'package:flutter/material.dart';
import '../models/trip_models.dart';
import '../services/payment_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class TripPaymentScreen extends StatefulWidget {
  final TripData tripData;
  final String serviceName;
  final String pickupAddress;
  final String destinationAddress;

  const TripPaymentScreen({
    super.key,
    required this.tripData,
    required this.serviceName,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  @override
  State<TripPaymentScreen> createState() => _TripPaymentScreenState();
}

class _TripPaymentScreenState extends State<TripPaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Créer le PaymentIntent via le backend
      final clientSecret = await PaymentService.createPaymentIntent(
        amount: widget.tripData.estimatedFare,
        currency: widget.tripData.currency,
        tripId: widget.tripData.id,
      );

      if (clientSecret == null) {
        throw Exception('Impossible de créer l\'intention de paiement');
      }

      // 2. Initialiser le Payment Sheet
      final initialized = await PaymentService.initPaymentSheet(
        clientSecret: clientSecret,
      );

      if (!initialized) {
        throw Exception('Erreur d\'initialisation du paiement');
      }

      // 3. Présenter le Payment Sheet
      final result = await PaymentService.presentPaymentSheet();

      if (result == PaymentResult.success) {
        _onPaymentSuccess();
      } else if (result == PaymentResult.failed) {
        setState(() {
          _errorMessage = 'Le paiement a échoué. Veuillez réessayer.';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _onPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('Paiement réussi !'),
          ],
        ),
        content: const Text(
          'Votre course est confirmée. Un chauffeur va vous rejoindre sous peu.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialogue
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/client_dashboard',
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Paiement de la course'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTripSummaryCard(),
            const SizedBox(height: 32),
            _buildPriceBreakdown(),
            const SizedBox(height: 40),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            CustomButton(
              text: _isProcessing ? 'Traitement...' : 'Payer maintenant',
              onPressed: _isProcessing ? null : _handlePayment,
              isLoading: _isProcessing,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Paiement sécurisé par Stripe',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_taxi, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Text(
                widget.serviceName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLocationItem(
            icon: Icons.my_location,
            color: Colors.green,
            label: 'Départ',
            address: widget.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 11, top: 4, bottom: 4),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(thickness: 2),
            ),
          ),
          _buildLocationItem(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'Destination',
            address: widget.destinationAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détail du prix',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildPriceRow('Tarif estimé', '${widget.tripData.estimatedFare} ${widget.tripData.currency}'),
        _buildPriceRow('Frais de service', '0.00 ${widget.tripData.currency}'),
        const Divider(height: 32),
        _buildPriceRow(
          'Total',
          '${widget.tripData.estimatedFare} ${widget.tripData.currency}',
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? AppTheme.primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

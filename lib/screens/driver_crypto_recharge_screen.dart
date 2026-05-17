import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/crypto_asset_model.dart';
import '../services/subscription_service.dart';
import '../utils/app_theme.dart';

class DriverCryptoRechargeScreen extends StatefulWidget {
  const DriverCryptoRechargeScreen({super.key});

  @override
  State<DriverCryptoRechargeScreen> createState() => _DriverCryptoRechargeScreenState();
}

class _DriverCryptoRechargeScreenState extends State<DriverCryptoRechargeScreen> {
  final SubscriptionService _subService = SubscriptionService();
  bool _copied = false;
  bool _verifying = false;

  @override
  Widget build(BuildContext context) {
    final asset = ModalRoute.of(context)?.settings.arguments as CryptoAsset?;

    // Fallback de sécurité si l'argument est manquant
    if (asset == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1017),
        body: Center(
          child: Text('Chargement...', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recharge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70),
            onPressed: () {
              // Historique de recharge
            },
          )
        ],
      ),
      body: _verifying 
        ? _buildVerificationLoader(asset)
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // QR Code & Network Container (matches second mockup)
                  _buildQrCodeCard(asset),
                  const SizedBox(height: 20),

                  // Deposit Address Box
                  _buildAddressBox(asset),
                  const SizedBox(height: 24),

                  // Action Button
                  ElevatedButton(
                    onPressed: () => _triggerBlockchainVerification(context, asset),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shadowColor: const Color(0xFF8247E5).withOpacity(0.3),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8247E5), // Purple
                            Color(0xFF3F51B5), // Blue/Violet
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        alignment: Alignment.center,
                        child: const Text(
                          'Recharge terminée',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // "Rappel chaleureux" section (matches second mockup)
                  _buildWarmReminder(asset),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildQrCodeCard(CryptoAsset asset) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Sélectionnez le réseau principal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Network Badge Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF8247E5)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              asset.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // QR Code Card Wrapper
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: asset.walletAddress,
              version: QrVersions.auto,
              size: 180.0,
              gapless: false,
              foregroundColor: const Color(0xFF0F1017),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBox(CryptoAsset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Adresse de dépôt',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161722),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  asset.walletAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              
              // Interactive Copy Button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: asset.walletAddress));
                  setState(() {
                    _copied = true;
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _copied = false;
                      });
                    }
                  });
                  HapticFeedback.lightImpact();
                },
                child: Text(
                  _copied ? 'Copié !' : 'Copie',
                  style: TextStyle(
                    color: _copied ? AppTheme.successColor : const Color(0xFF009387),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarmReminder(CryptoAsset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Rappel chaleureux',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '1. Copiez l\'adresse ci-dessus ou scannez le code QR, puis sélectionnez le réseau ${asset.network} pour transférer vos cryptomonnaies vers ce compte.',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '2. L\'envoi de tout autre actif de cryptomonnaie sur cette adresse (y compris d\'autres réseaux non compatibles) entraînera la perte définitive de vos fonds.',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationLoader(CryptoAsset asset) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF8247E5),
              strokeWidth: 5,
            ),
            const SizedBox(height: 30),
            const Text(
              'Vérification Blockchain',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recherche de transactions sur le réseau ${asset.network}...\nCela peut prendre quelques instants.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerBlockchainVerification(BuildContext context, CryptoAsset asset) async {
    setState(() {
      _verifying = true;
    });

    // Appel au service pour simuler la blockchain
    final success = await _subService.confirmCryptoPayment(asset, '0xMockTxHash123456');

    if (success && mounted) {
      setState(() {
        _verifying = false;
      });

      // Afficher un overlay ou snackbar de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.verified_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Abonnement activé avec succès ! Merci de faire confiance à AtlasMove.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Rediriger vers l'historique ou le dashboard
      Navigator.popUntil(context, (route) => route.settings.name == '/driver_main' || route.isFirst);
    }
  }
}
